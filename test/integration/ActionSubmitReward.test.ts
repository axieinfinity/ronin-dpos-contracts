import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
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
} from '../../src/types';
import { mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import { EpochController } from '../helpers/ronin-validator-set';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const unavailabilityTier2Threshold = 10;
const slashAmountForUnavailabilityTier2Threshold = BigNumber.from(1);
const slashDoubleSignAmount = 1000;
const minValidatorBalance = BigNumber.from(100);
const blockProducerBonusPerBlock = BigNumber.from(1);

describe('[Integration] Submit Block Reward', () => {
  const blockRewardAmount = BigNumber.from(2);

  before(async () => {
    [deployer, coinbase, governor, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress, roninGovernanceAdminAddress } =
      await initTest('ActionSubmitReward')({
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
          minValidatorBalance,
        },
        stakingVestingArguments: {
          blockProducerBonusPerBlock,
        },
        roninTrustedOrganizationArguments: {
          trustedOrganizations: [governor].map((v) => ({
            consensusAddr: v.address,
            governor: v.address,
            bridgeVoter: v.address,
            weight: 100,
            addedBlock: 0,
          })),
        },
      });

    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
  });

  describe('Configuration check', async () => {
    describe('ValidatorSetContract configuration', async () => {
      it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
        let _stakingContract = await validatorContract.stakingContract();
        expect(_stakingContract).to.eq(stakingContract.address);
      });

      it('Should the ValidatorSetContract config the Slashing correctly', async () => {
        let _slashingContract = await validatorContract.slashIndicatorContract();
        expect(_slashingContract).to.eq(slashContract.address);
      });
    });

    describe('StakingContract configuration', async () => {
      it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
        let _validatorSetContract = await stakingContract.validatorContract();
        expect(_validatorSetContract).to.eq(validatorContract.address);
      });
    });
  });

  describe('One validator submits block reward', async () => {
    let validator: SignerWithAddress;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorBalance.mul(2);
      validator = validatorCandidates[0];
      await stakingContract
        .connect(validator)
        .applyValidatorCandidate(validator.address, validator.address, validator.address, validator.address, 2_00, {
          value: initStakingAmount,
        });

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
      await network.provider.send('hardhat_setCoinbase', [validator.address]);
      validatorContract = validatorContract.connect(validator);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of submitting reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'BlockRewardSubmitted')
        .withArgs(validator.address, blockRewardAmount, blockProducerBonusPerBlock);
    });

    it.skip('Should the ValidatorSetContract update mining reward', async () => {});

    it('Should the StakingContract emit event of recording reward', async () => {
      await expect(submitRewardTx).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(validator.address, anyValue);
    });

    it.skip('Should the StakingContract record update for new block reward', async () => {});
  });

  describe('In-jail validator submits block reward', async () => {
    let validator: SignerWithAddress;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorBalance.mul(2);
      validator = validatorCandidates[1];

      await stakingContract
        .connect(validator)
        .applyValidatorCandidate(validator.address, validator.address, validator.address, validator.address, 2_00, {
          value: initStakingAmount,
        });

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      for (let i = 0; i < unavailabilityTier2Threshold; i++) {
        await slashContract.connect(coinbase).slashUnavailability(validator.address);
      }
    });

    it('Should in-jail validator submit block reward', async () => {
      await network.provider.send('hardhat_setCoinbase', [validator.address]);
      validatorContract = validatorContract.connect(validator);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of deprecating reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'BlockRewardRewardDeprecated')
        .withArgs(validator.address, blockRewardAmount);
    });

    it('Should the StakingContract not emit event of recording reward', async () => {
      expect(submitRewardTx).not.to.emit(stakingContract, 'PendingPoolUpdated');
    });
  });
});
