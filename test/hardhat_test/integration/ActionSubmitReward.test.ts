import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, ContractTransaction } from 'ethers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetExtended__factory,
  MockRoninValidatorSetExtended,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
} from '../../../src/types';
import { ContractType, mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { EpochController } from '../helpers/ronin-validator-set';
import { BlockRewardDeprecatedType } from '../../../src/script/ronin-validator-set';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

const unavailabilityTier2Threshold = 10;
const slashAmountForUnavailabilityTier2Threshold = BigNumber.from(1);
const slashDoubleSignAmount = 10000;
const minValidatorStakingAmount = BigNumber.from(1000);
const blockProducerBonusPerBlock = BigNumber.from(200);

describe('[Integration] Submit Block Reward', () => {
  const blockRewardAmount = BigNumber.from(100);

  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();

    validatorCandidates = createManyValidatorCandidateAddressSets(signers.splice(0, 2 * 3));
    trustedOrgs = createManyTrustedOrganizationAddressSets([...signers.slice(0, 1 * 3)]);

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const {
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
      fastFinalityTrackingAddress,
    } = await initTest('ActionSubmitReward')({
      slashIndicatorArguments: {
        unavailabilitySlashing: {
          unavailabilityTier2Threshold,
          slashAmountForUnavailabilityTier2Threshold,
        },
        doubleSignSlashing: {
          slashDoubleSignAmount,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      stakingVestingArguments: {
        blockProducerBonusPerBlock,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
    });

    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initEpoch();
    await validatorContract.initializeV3(fastFinalityTrackingAddress);
  });

  describe('Configuration check', async () => {
    describe('ValidatorSetContract configuration', async () => {
      it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
        let _stakingContract = await validatorContract.getContract(ContractType.STAKING);
        expect(_stakingContract).to.eq(stakingContract.address);
      });

      it('Should the ValidatorSetContract config the Slashing correctly', async () => {
        let _slashingContract = await validatorContract.getContract(ContractType.SLASH_INDICATOR);
        expect(_slashingContract).to.eq(slashContract.address);
      });
    });

    describe('StakingContract configuration', async () => {
      it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
        let _validatorSetContract = await stakingContract.getContract(ContractType.VALIDATOR);
        expect(_validatorSetContract).to.eq(validatorContract.address);
      });
    });
  });

  describe('One validator submits block reward', async () => {
    let validator: ValidatorCandidateAddressSet;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorStakingAmount.mul(2);
      validator = validatorCandidates[0];
      await stakingContract
        .connect(validator.poolAdmin)
        .applyValidatorCandidate(
          validator.candidateAdmin.address,
          validator.consensusAddr.address,
          validator.treasuryAddr.address,
          2_00,
          {
            value: initStakingAmount,
          }
        );

      await EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });
    });

    after(async () => {
      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    });

    it('Should validator can submit block reward', async () => {
      await network.provider.send('hardhat_setCoinbase', [validator.consensusAddr.address]);
      validatorContract = validatorContract.connect(validator.consensusAddr);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of submitting reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'BlockRewardSubmitted')
        .withArgs(validator.consensusAddr.address, blockRewardAmount, blockProducerBonusPerBlock);
    });

    it.skip('Should the ValidatorSetContract update mining reward', async () => {});

    it.skip('Should the StakingContract record update for new block reward', async () => {});
  });

  describe('In-jail validator submits block reward', async () => {
    let validator: ValidatorCandidateAddressSet;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorStakingAmount.mul(2);
      validator = validatorCandidates[1];

      await stakingContract
        .connect(validator.poolAdmin)
        .applyValidatorCandidate(
          validator.candidateAdmin.address,
          validator.consensusAddr.address,
          validator.treasuryAddr.address,
          2_00,
          {
            value: initStakingAmount,
          }
        );

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      for (let i = 0; i < unavailabilityTier2Threshold; i++) {
        await slashContract.connect(coinbase).slashUnavailability(validator.consensusAddr.address);
      }
    });

    it('Should in-jail validator submit block reward', async () => {
      await network.provider.send('hardhat_setCoinbase', [validator.consensusAddr.address]);
      validatorContract = validatorContract.connect(validator.consensusAddr);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of deprecating reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'BlockRewardDeprecated')
        .withArgs(validator.consensusAddr.address, blockRewardAmount, BlockRewardDeprecatedType.UNAVAILABILITY);
    });

    it('Should the StakingContract not emit event of recording reward', async () => {
      await expect(submitRewardTx).not.to.emit(stakingContract, 'PoolsUpdated');
    });
  });
});
