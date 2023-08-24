import { BigNumber, ContractTransaction } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';

import {
  Maintenance,
  Maintenance__factory,
  MockRoninValidatorSetOverridePrecompile__factory,
  MockSlashIndicatorExtended,
  MockSlashIndicatorExtended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  RoninValidatorSet,
  Staking,
  Staking__factory,
} from '../../../src/types';
import { initTest } from '../helpers/fixture';
import { EpochController, expects as RoninValidatorSetExpects } from '../helpers/ronin-validator-set';
import { expects as CandidateManagerExpects } from '../helpers/candidate-manager';
import { IndicatorController, ScoreController } from '../helpers/slash';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { SlashType } from '../../../src/script/slash-indicator';
import { BlockRewardDeprecatedType } from '../../../src/script/ronin-validator-set';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';

let maintenanceContract: Maintenance;
let slashContract: MockSlashIndicatorExtended;
let mockSlashLogic: MockSlashIndicatorExtended;
let stakingContract: Staking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorContract: RoninValidatorSet;

let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

let localIndicatorController: IndicatorController;
let localScoreController: ScoreController;
let localEpochController: EpochController;

let snapshotId: string;

const gainCreditScore = 50;
const maxCreditScore = 600;
const bailOutCostMultiplier = 5;

const unavailabilityTier1Threshold = 5;
const unavailabilityTier2Threshold = 15;
const slashAmountForUnavailabilityTier2Threshold = 2;

const minValidatorStakingAmount = BigNumber.from(100);
const maxValidatorCandidate = 3;
const maxValidatorNumber = 2;
const numberOfBlocksInEpoch = 600;
const minOffsetToStartSchedule = 200;

const blockProducerBonusPerBlock = BigNumber.from(5000);
const submittedRewardEachBlock = BigNumber.from(60);

const waitingSecsToRevoke = 7 * 86400;

const minMaintenanceDurationInBlock = 100;

const wrapUpEpoch = async (): Promise<ContractTransaction> => {
  await localEpochController.mineToBeforeEndOfEpoch();
  await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
  return await validatorContract.connect(coinbase).wrapUpEpoch();
};

const endPeriodAndWrapUpAndResetIndicators = async (includingEpochsNum?: number): Promise<ContractTransaction> => {
  if (includingEpochsNum) {
    expect(includingEpochsNum).gt(0);
  }

  await localEpochController.mineToBeforeEndOfEpoch(includingEpochsNum);
  await EpochController.setTimestampToPeriodEnding();
  let wrapUpTx = await wrapUpEpoch();

  validatorCandidates.map((_, i) => localIndicatorController.resetAt(i));

  return wrapUpTx;
};

const slashValidatorUntilTier = async (
  slasherIdx: number,
  slasheeIdx: number,
  slashType: SlashType
): Promise<ContractTransaction | undefined> => {
  let _threshold;
  switch (slashType) {
    case SlashType.UNAVAILABILITY_TIER_1:
      _threshold = unavailabilityTier1Threshold;
      break;
    case SlashType.UNAVAILABILITY_TIER_2:
      _threshold = unavailabilityTier2Threshold;
      break;
    case SlashType.UNAVAILABILITY_TIER_3:
      _threshold = unavailabilityTier1Threshold;
      break;
    default:
      return;
  }

  let tx;
  let slasher = validatorCandidates[slasherIdx];
  let slashee = validatorCandidates[slasheeIdx];

  await network.provider.send('hardhat_setCoinbase', [slasher.consensusAddr.address]);

  let _toSlashTimes = _threshold - localIndicatorController.getAt(slasheeIdx);

  for (let i = 0; i < _toSlashTimes; i++) {
    tx = await slashContract.connect(slasher.consensusAddr).slashUnavailability(slashee.consensusAddr.address);
  }

  let period = await validatorContract.currentPeriod();
  await expect(tx).to.emit(slashContract, 'Slashed').withArgs(slashee.consensusAddr.address, slashType, period);
  localIndicatorController.setAt(slasheeIdx, _threshold);
  return tx;
};

const validateScoreAt = async (idx: number) => {
  expect(await slashContract.getCreditScore(validatorCandidates[idx].consensusAddr.address)).to.eq(
    localScoreController.getAt(idx)
  );
};

const validateIndicatorAt = async (idx: number) => {
  expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[idx].consensusAddr.address)).to.eq(
    localIndicatorController.getAt(idx)
  );
};

describe('Credit score and bail out test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, (maxValidatorNumber + 1) * 3));

    const {
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
      maintenanceContractAddress,
      fastFinalityTrackingAddress
    } = await initTest('CreditScore')({
      slashIndicatorArguments: {
        unavailabilitySlashing: {
          unavailabilityTier1Threshold,
          unavailabilityTier2Threshold,
          slashAmountForUnavailabilityTier2Threshold,
        },
        creditScore: {
          gainCreditScore,
          maxCreditScore,
          bailOutCostMultiplier,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      stakingVestingArguments: {
        blockProducerBonusPerBlock,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        numberOfBlocksInEpoch,
        maxValidatorCandidate,
      },
      maintenanceArguments: {
        minOffsetToStartSchedule,
        minMaintenanceDurationInBlock,
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

    maintenanceContract = Maintenance__factory.connect(maintenanceContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetOverridePrecompile__factory.connect(validatorContractAddress, deployer);
    slashContract = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetOverridePrecompile__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initializeV3(fastFinalityTrackingAddress);

    mockSlashLogic = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashLogic.deployed();
    await governanceAdminInterface.upgrade(slashContractAddress, mockSlashLogic.address);

    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          100_00,
          { value: minValidatorStakingAmount.mul(2).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    localEpochController = new EpochController(minOffsetToStartSchedule, numberOfBlocksInEpoch);
    await localEpochController.mineToBeforeEndOfEpoch(2);
    await validatorContract.connect(coinbase).wrapUpEpoch();
    expect(await validatorContract.getValidators()).deep.equal(
      validatorCandidates.slice(0, maxValidatorNumber).map((_) => _.consensusAddr.address)
    );
    expect(await validatorContract.getBlockProducers()).deep.equal(
      validatorCandidates.slice(0, maxValidatorNumber).map((_) => _.consensusAddr.address)
    );

    localIndicatorController = new IndicatorController(validatorCandidates.length);
    localScoreController = new ScoreController(validatorCandidates.length);
  });

  describe('Counting credit score after each period', async () => {
    it('Should the score updated correctly, case: max score (N), in jail (N), unavailability (N)', async () => {
      await endPeriodAndWrapUpAndResetIndicators();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
      await validateScoreAt(0);
    });
    it('Should the score updated correctly, case: max score (N), in jail (N), unavailability (y)', async () => {
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[1].consensusAddr.address]);
      await slashContract
        .connect(validatorCandidates[1].consensusAddr)
        .slashUnavailability(validatorCandidates[0].consensusAddr.address);
      localIndicatorController.increaseAt(1);
      await endPeriodAndWrapUpAndResetIndicators();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore - 1);
      await validateScoreAt(0);
    });
    it('Should the score updated correctly, case: max score (N), in jail (y), unavailability (N)', async () => {
      await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_2);
      await wrapUpEpoch();
      await endPeriodAndWrapUpAndResetIndicators();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, 0);
      await validateScoreAt(0);

      let _jailLeft = await validatorContract.getJailedTimeLeft(validatorCandidates[0].consensusAddr.address);
      await network.provider.send('hardhat_mine', [_jailLeft.blockLeft_.toHexString(), '0x0']);
    });
    it('Should the score updated correctly, case: max score (y), in jail (N), unavailability (N)', async () => {
      for (let i = 0; i < maxCreditScore / gainCreditScore + 1; i++) {
        await endPeriodAndWrapUpAndResetIndicators();
        localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
        await validateScoreAt(0);
      }
    });
    it('Should the score get reset when the candidate is revoked', async () => {
      await stakingContract
        .connect(validatorCandidates[0].poolAdmin)
        .requestRenounce(validatorCandidates[0].consensusAddr.address);
      await network.provider.send('evm_increaseTime', [waitingSecsToRevoke]);

      let tx = await endPeriodAndWrapUpAndResetIndicators();
      await CandidateManagerExpects.emitCandidatesRevokedEvent(tx, [validatorCandidates[0].consensusAddr.address]);
      await expect(tx)
        .emit(slashContract, 'CreditScoresUpdated')
        .withArgs([validatorCandidates[0].consensusAddr.address], [0]);

      localScoreController.resetAt(0);
      await validateScoreAt(0);

      await stakingContract
        .connect(validatorCandidates[0].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[0].candidateAdmin.address,
          validatorCandidates[0].consensusAddr.address,
          validatorCandidates[0].treasuryAddr.address,
          100_00,
          { value: minValidatorStakingAmount.mul(2) }
        );

      await endPeriodAndWrapUpAndResetIndicators();
    });
  });

  describe('Credit score and maintenance', async () => {
    let currentBlock;
    let startedAtBlock;
    let endedAtBlock;

    it("Should the credit score increase before validator's maintenance", async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock).add(numberOfBlocksInEpoch);
      endedAtBlock = localEpochController.calculateEndOfEpoch(
        BigNumber.from(startedAtBlock).add(minMaintenanceDurationInBlock)
      );

      const tx = await maintenanceContract
        .connect(validatorCandidates[0].candidateAdmin)
        .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock);
      await expect(tx)
        .emit(maintenanceContract, 'MaintenanceScheduled')
        .withArgs(validatorCandidates[0].consensusAddr.address, [startedAtBlock, endedAtBlock]);
      expect(await maintenanceContract.checkScheduled(validatorCandidates[0].consensusAddr.address)).true;

      await endPeriodAndWrapUpAndResetIndicators(2);
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
      await validateScoreAt(0);
    });

    it('Should the credit score not increase when validator is on maintenance', async () => {
      await endPeriodAndWrapUpAndResetIndicators(1);
      await validateScoreAt(0);
    });

    it('Should the credit score increase when validator finishes maintenance', async () => {
      await endPeriodAndWrapUpAndResetIndicators(1);
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
      await validateScoreAt(0);
    });
  });

  describe('Bail out test', async () => {
    describe('Sanity check', async () => {
      it('Should the non admin candidate cannot call the bail out function', async () => {
        await expect(
          slashContract
            .connect(validatorCandidates[0].consensusAddr)
            .bailOut(validatorCandidates[0].consensusAddr.address)
        ).revertedWithCustomError(slashContract, 'ErrUnauthorized');
      });
      it('Should not be able to call the bail out function with param of non-candidate consensus address ', async () => {
        await expect(
          slashContract
            .connect(validatorCandidates[0].candidateAdmin)
            .bailOut(validatorCandidates[2].consensusAddr.address)
        ).revertedWithCustomError(slashContract, 'ErrUnauthorized');
      });
    });

    describe('Bailing out from a validator but non-block-producer', async () => {
      before(async () => {
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);

        let submitRewardTx = await validatorContract
          .connect(validatorCandidates[0].consensusAddr)
          .submitBlockReward({ value: submittedRewardEachBlock });
        await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(
          submitRewardTx,
          validatorCandidates[0].consensusAddr.address,
          submittedRewardEachBlock,
          blockProducerBonusPerBlock
        );

        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);

        await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

        for (let i = 0; i < Math.floor(maxCreditScore / gainCreditScore); i++) {
          await endPeriodAndWrapUpAndResetIndicators();
        }
        localScoreController.increaseAtWithUpperbound(0, maxCreditScore, maxCreditScore);

        await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_2);
        let wrapUpTx = await wrapUpEpoch();
        expect(wrapUpTx).emit(validatorContract, 'WrappedUpEpoch').withArgs([anyValue, anyValue, false]);

        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(false);
      });

      let tx: ContractTransaction;

      it('Should the bailing out cost subtracted correctly', async () => {
        let _latestBlockNum = BigNumber.from(await network.provider.send('eth_blockNumber'));
        let _jailLeft = await validatorContract.getJailedTimeLeftAtBlock(
          validatorCandidates[0].consensusAddr.address,
          _latestBlockNum.add(1)
        );

        tx = await slashContract
          .connect(validatorCandidates[0].candidateAdmin)
          .bailOut(validatorCandidates[0].consensusAddr.address);
        let _period = await validatorContract.currentPeriod();
        let _cost = bailOutCostMultiplier * _jailLeft.epochLeft_.toNumber();
        localScoreController.subAtNonNegative(0, _cost);
        await validateScoreAt(0);

        await expect(tx)
          .emit(slashContract, 'BailedOut')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period, _cost);
        await expect(tx)
          .emit(validatorContract, 'ValidatorUnjailed')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period);
      });

      it('Should the indicator get reset', async () => {
        localIndicatorController.resetAt(0);
        await validateIndicatorAt(0);
      });

      it.skip('Should the rewards of the validator before the bailout get removed', async () => {
        /// Rewards have been removed in `slash` function
      });

      it('Should the bailed out validator becomes block producer in the next epoch', async () => {
        await wrapUpEpoch();
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });

      it('Should the rewards of the validator after the bailout get cut in half', async () => {
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);

        let submitRewardTx = await validatorContract
          .connect(validatorCandidates[0].consensusAddr)
          .submitBlockReward({ value: submittedRewardEachBlock });

        await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(
          submitRewardTx,
          validatorCandidates[0].consensusAddr.address,
          submittedRewardEachBlock,
          blockProducerBonusPerBlock
        );

        await RoninValidatorSetExpects.emitBlockRewardDeprecatedEvent(
          submitRewardTx,
          validatorCandidates[0].consensusAddr.address,
          submittedRewardEachBlock.add(blockProducerBonusPerBlock).div(2),
          BlockRewardDeprecatedType.AFTER_BAILOUT
        );

        await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      });

      it('Should the wrapping up period tx distribute correct reward amount', async () => {
        let tx = await endPeriodAndWrapUpAndResetIndicators();
        await localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);

        await expect(tx)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(
            validatorCandidates[0].consensusAddr.address,
            validatorCandidates[0].poolAdmin.address,
            submittedRewardEachBlock.add(blockProducerBonusPerBlock).div(2)
          );
      });
    });

    describe('Insufficient credit score to bail out', async () => {
      before(async () => {
        await endPeriodAndWrapUpAndResetIndicators();
        localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
        await validateScoreAt(0);
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);

        await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_2);
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });

      it('Should not be able to bail out due to insufficient credit score', async () => {
        await expect(
          slashContract
            .connect(validatorCandidates[0].candidateAdmin)
            .bailOut(validatorCandidates[0].consensusAddr.address)
        ).revertedWithCustomError(slashContract, 'ErrInsufficientCreditScoreToBailOut');
      });

      it('Should the slashed validator become block producer when jailed time over', async () => {
        let _jailEpochLeft = (await validatorContract.getJailedTimeLeft(validatorCandidates[0].consensusAddr.address))
          .epochLeft_;
        await endPeriodAndWrapUpAndResetIndicators(_jailEpochLeft.toNumber());
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });
    });

    describe('Bailing out from a to-be-in-jail validator', async () => {
      before(async () => {
        for (let i = 0; i < maxCreditScore / gainCreditScore + 1; i++) {
          await endPeriodAndWrapUpAndResetIndicators();
          await localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
        }

        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
        await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_2);
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });

      it('Should the bailing out cost subtracted correctly', async () => {
        let _jailLeft = await validatorContract.getJailedTimeLeft(validatorCandidates[0].consensusAddr.address);
        let tx = await slashContract
          .connect(validatorCandidates[0].candidateAdmin)
          .bailOut(validatorCandidates[0].consensusAddr.address);
        let _period = await validatorContract.currentPeriod();
        let _cost = bailOutCostMultiplier * _jailLeft.epochLeft_.toNumber();
        localScoreController.subAtNonNegative(0, _cost);
        await validateScoreAt(0);

        await expect(tx)
          .emit(slashContract, 'BailedOut')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period, _cost);
        await expect(tx)
          .emit(validatorContract, 'ValidatorUnjailed')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period);
      });

      it('Should the indicator get reset', async () => {
        localIndicatorController.resetAt(0);
        await validateIndicatorAt(0);
      });

      it.skip('Should the rewards of the validator before the bailout get removed', async () => {
        /// Rewards have been removed in `slash` function
      });

      it('Should the rewards of the validator after the bailout get cut in half', async () => {
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);

        let submitRewardTx = await validatorContract
          .connect(validatorCandidates[0].consensusAddr)
          .submitBlockReward({ value: submittedRewardEachBlock });

        await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(
          submitRewardTx,
          validatorCandidates[0].consensusAddr.address,
          submittedRewardEachBlock,
          blockProducerBonusPerBlock
        );

        await RoninValidatorSetExpects.emitBlockRewardDeprecatedEvent(
          submitRewardTx,
          validatorCandidates[0].consensusAddr.address,
          submittedRewardEachBlock.add(blockProducerBonusPerBlock).div(2),
          BlockRewardDeprecatedType.AFTER_BAILOUT
        );

        await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      });

      it('Should the bailed out validator still is block producer in the next epoch', async () => {
        await wrapUpEpoch();
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });

      it('Should the wrapping up period tx distribute correct reward amount', async () => {
        let tx = await endPeriodAndWrapUpAndResetIndicators();
        await localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);

        await expect(tx)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(
            validatorCandidates[0].consensusAddr.address,
            validatorCandidates[0].poolAdmin.address,
            submittedRewardEachBlock.add(blockProducerBonusPerBlock).div(2)
          );
      });
    });

    describe('Bailing out from a validator that has been bailed out previously', async () => {
      let tx: ContractTransaction | undefined;
      before(async () => {
        for (let i = 0; i < maxCreditScore / gainCreditScore + 1; i++) {
          await endPeriodAndWrapUpAndResetIndicators();
          await localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
        }

        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
        await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_2);
        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);

        let _latestBlockNum = BigNumber.from(await network.provider.send('eth_blockNumber'));
        let _jailLeft = await validatorContract.getJailedTimeLeftAtBlock(
          validatorCandidates[0].consensusAddr.address,
          _latestBlockNum.add(1)
        );

        let _jailEpochLeft = _jailLeft.epochLeft_;
        await localEpochController.mineToBeforeEndOfEpoch(_jailEpochLeft.sub(1));
        await wrapUpEpoch();

        let tx = await slashContract
          .connect(validatorCandidates[0].candidateAdmin)
          .bailOut(validatorCandidates[0].consensusAddr.address);
        let _period = await validatorContract.currentPeriod();
        let _cost = bailOutCostMultiplier * 1;

        localIndicatorController.resetAt(0);
        await validateIndicatorAt(0);

        localScoreController.subAtNonNegative(0, _cost);
        await validateScoreAt(0);

        await localEpochController.mineToBeforeEndOfEpoch();
        await wrapUpEpoch();

        await expect(tx)
          .emit(slashContract, 'BailedOut')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period, _cost);
        await expect(tx)
          .emit(validatorContract, 'ValidatorUnjailed')
          .withArgs(validatorCandidates[0].consensusAddr.address, _period);

        expect(await validatorContract.isBlockProducer(validatorCandidates[0].consensusAddr.address)).eq(true);
      });

      it('Should the bailed-out-validator is slashed with tier-3', async () => {
        tx = await slashValidatorUntilTier(1, 0, SlashType.UNAVAILABILITY_TIER_3);
      });

      it('Should the validator get deducted staking amount when reaching tier-3', async () => {
        await expect(tx)
          .emit(validatorContract, 'ValidatorPunished')
          .withArgs(
            validatorCandidates[0].consensusAddr.address,
            anyValue,
            anyValue,
            slashAmountForUnavailabilityTier2Threshold,
            true,
            false
          );
      });

      it('Should the bailed-out-validator not be able to bail out the second time in the same period', async () => {
        await expect(
          slashContract
            .connect(validatorCandidates[0].candidateAdmin)
            .bailOut(validatorCandidates[0].consensusAddr.address)
        ).revertedWithCustomError(slashContract, 'ErrValidatorHasBailedOutPreviously');
      });
    });

    describe('Bailing out from validator in tier-3', async () => {
      it('Should the tier-3-slashed validator cannot bail out', async () => {
        await endPeriodAndWrapUpAndResetIndicators();
        await expect(
          slashContract
            .connect(validatorCandidates[0].candidateAdmin)
            .bailOut(validatorCandidates[0].consensusAddr.address)
        )
          .revertedWithCustomError(validatorContract, 'ErrCannotBailout')
          .withArgs(validatorCandidates[0].consensusAddr.address);
      });
    });
  });
});
