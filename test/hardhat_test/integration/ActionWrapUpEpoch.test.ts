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
import { expects as StakingExpects } from '../helpers/staking';
import { EpochController, expects as ValidatorSetExpects } from '../helpers/ronin-validator-set';
import { ContractType, mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { Address } from 'hardhat-deploy/dist/types';
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
const slashDoubleSignAmount = 1000;
const minValidatorStakingAmount = BigNumber.from(100);
const maxValidatorNumber = 3;

describe('[Integration] Wrap up epoch', () => {
  const blockRewardAmount = BigNumber.from(2);

  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.splice(0, maxValidatorNumber * 3 * 3));

    const {
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
      fastFinalityTrackingAddress,
    } = await initTest('ActionWrapUpEpoch')({
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
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
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

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Configuration test', () => {
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

    describe('SlashIndicatorContract configuration', async () => {
      it('Should the SlashIndicatorContract config the ValidatorSetContract correctly', async () => {
        let _validatorSetContract = await slashContract.getContract(ContractType.VALIDATOR);
        expect(_validatorSetContract).to.eq(validatorContract.address);
      });
    });
  });

  describe('Flow test on one validator', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: ValidatorCandidateAddressSet[];

    before(async () => {
      validators = validatorCandidates.slice(0, 4);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validatorCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            validatorCandidates[i].candidateAdmin.address,
            validatorCandidates[i].consensusAddr.address,
            validatorCandidates[i].treasuryAddr.address,
            2_00,
            {
              value: minValidatorStakingAmount.mul(2).add(i),
            }
          );
      }

      await EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      await network.provider.send('hardhat_setCoinbase', [validators[3].consensusAddr.address]);
      validatorContract = validatorContract.connect(validators[3].consensusAddr);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });

      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      validatorContract = validatorContract.connect(coinbase);
    });

    describe('Wrap up epoch: at the end of the epoch', async () => {
      it('Should validator not be able to wrap up the epoch twice, in the same epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
          let duplicatedWrapUpTx = validatorContract.wrapUpEpoch();
          await expect(duplicatedWrapUpTx).to.be.revertedWithCustomError(validatorContract, 'ErrAlreadyWrappedEpoch');
        });
      });

      it('Should validator be able to wrap up the epoch', async () => {
        await network.provider.send('evm_increaseTime', [86400]);
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
      });

      describe.skip('ValidatorSetContract internal actions', async () => {});

      describe('StakingContract internal actions: settle reward pool', async () => {
        it('Should the StakingContract emit event of settling reward', async () => {
          await StakingExpects.emitPoolsUpdatedEvent(
            wrapUpTx,
            undefined,
            validators
              .slice(1, 4)
              .map((_) => _.consensusAddr.address)
              .reverse()
          );
        });
      });
    });

    describe('Wrap up epoch: at the end of the period', async () => {
      before(async () => {
        await validatorContract.addValidators(validators.map((v) => v.consensusAddr.address));
        await Promise.all(
          validators.map((v) => slashContract.connect(coinbase).slashUnavailability(v.consensusAddr.address))
        );
      });

      it('Should the ValidatorSet not reset counter, when the period is not ended', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expect(
          await Promise.all(
            validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.consensusAddr.address))
          )
        ).deep.equal(
          validators.map((v) => (v.consensusAddr.address == coinbase.address ? BigNumber.from(0) : BigNumber.from(1)))
        );
      });

      it('Should the ValidatorSet reset counter in SlashIndicator contract', async () => {
        await network.provider.send('evm_increaseTime', [86400]);
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expect(
          await Promise.all(
            validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.consensusAddr.address))
          )
        ).deep.equal(validators.map(() => BigNumber.from(0)));
      });
    });
  });

  describe('Flow test on many validators', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: ValidatorCandidateAddressSet[];

    before(async () => {
      validators = validatorCandidates.slice(4, 8);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validators[i].poolAdmin)
          .applyValidatorCandidate(
            validators[i].candidateAdmin.address,
            validators[i].consensusAddr.address,
            validators[i].treasuryAddr.address,
            2_00,
            {
              value: minValidatorStakingAmount.mul(3).add(i),
            }
          );
      }

      await EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      coinbase = validators[3].consensusAddr;
      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      validatorContract = validatorContract.connect(coinbase);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    describe('One validator get slashed between period', async () => {
      let slasheeAddress: Address;

      before(async () => {
        slasheeAddress = validators[1].consensusAddr.address;
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
        });

        for (let i = 0; i < unavailabilityTier2Threshold; i++) {
          await slashContract.connect(coinbase).slashUnavailability(slasheeAddress);
        }
      });

      it('Should the block producer set get updated (excluding the slashed validator)', async () => {
        const lastPeriod = await validatorContract.currentPeriod();
        const epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });

        let expectingBlockProducerSet = [validators[2], validators[3]].map((_) => _.consensusAddr.address).reverse();

        await expect(wrapUpTx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, false);
        await ValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
          wrapUpTx!,
          lastPeriod,
          await validatorContract.epochOf((await ethers.provider.getBlockNumber()) + 1),
          expectingBlockProducerSet
        );

        expect(await validatorContract.getValidators()).deep.equal(
          [validators[1], validators[2], validators[3]].map((_) => _.consensusAddr.address).reverse()
        );
        expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
      });

      it('Should the validators in the previous epoch (including slashed one) got slashing counter reset, when the epoch ends', async () => {
        await network.provider.send('evm_increaseTime', [86400]);
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        expect(
          await Promise.all(
            validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.consensusAddr.address))
          )
        ).deep.equal(validators.map(() => BigNumber.from(0)));
      });
    });
  });
});
