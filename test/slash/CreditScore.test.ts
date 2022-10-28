import { BigNumber, BytesLike, Transaction } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockRoninValidatorSetOverridePrecompile__factory,
  MockSlashIndicatorExtended,
  MockSlashIndicatorExtended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  RoninValidatorSet,
  Staking,
  Staking__factory,
} from '../../src/types';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
import { IndicatorController, ScoreController } from '../helpers/slash';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import { SlashType } from '../../src/script/slash-indicator';

let slashContract: MockSlashIndicatorExtended;
let mockSlashLogic: MockSlashIndicatorExtended;
let stakingContract: Staking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorContract: RoninValidatorSet;
let vagabond: SignerWithAddress;
let candidateAdmins: SignerWithAddress[];
let validatorCandidates: SignerWithAddress[];

let localIndicatorController: IndicatorController;
let localScoreController: ScoreController;
let localEpochController: EpochController;

const gainCreditScore = 50;
const maxCreditScore = 600;
const bailOutCostMultiplier = 5;

const misdemeanorThreshold = 5;
const felonyThreshold = 15;
const slashFelonyAmount = 2;

const minValidatorBalance = BigNumber.from(100);
const maxValidatorNumber = 5;
const numberOfBlocksInEpoch = 600;
const minOffset = 200;

const wrapUpEpoch = async () => {
  await localEpochController.mineToBeforeEndOfEpoch();
  await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
  await validatorContract.connect(coinbase).wrapUpEpoch();
};

const endPeriodAndWrapUpAndResetIndicators = async (includingEpochsNum?: number) => {
  if (includingEpochsNum) {
    expect(includingEpochsNum).gt(0);
  }

  includingEpochsNum = includingEpochsNum ? includingEpochsNum - 1 : 0;
  for (let i = 0; i < includingEpochsNum; i++) {
    await localEpochController.mineToBeforeEndOfEpoch();
  }
  await EpochController.setTimestampToPeriodEnding();
  await wrapUpEpoch();

  validatorCandidates.map((_, i) => localIndicatorController.resetAt(i));
};

const slashUntilValidatorTier = async (slasherIdx: number, slasheeIdx: number, tier: number) => {
  if (tier != 1 && tier != 2) {
    return;
  }

  let _threshold = tier == 1 ? misdemeanorThreshold : felonyThreshold;
  let _slashType = tier == 1 ? SlashType.MISDEMEANOR : SlashType.FELONY;

  let tx;
  let slasher = validatorCandidates[slasherIdx];
  let slashee = validatorCandidates[slasheeIdx];

  await network.provider.send('hardhat_setCoinbase', [slasher.address]);

  let _toSlashTimes = _threshold - localIndicatorController.getAt(slasheeIdx);

  for (let i = 0; i < _toSlashTimes; i++) {
    tx = await slashContract.connect(slasher).slash(slashee.address);
  }

  let period = await validatorContract.currentPeriod();
  await expect(tx).to.emit(slashContract, 'UnavailabilitySlashed').withArgs(slashee.address, _slashType, period);
  localIndicatorController.setAt(slasheeIdx, _threshold);
};

const validateScoreAt = async (idx: number) => {
  expect(await slashContract.getCreditScore(validatorCandidates[idx].address)).to.eq(localScoreController.getAt(idx));
};

describe('Credit score and bail out test', () => {
  before(async () => {
    [deployer, coinbase, governor, vagabond, ...validatorCandidates] = await ethers.getSigners();

    candidateAdmins = validatorCandidates.slice(0, maxValidatorNumber);
    validatorCandidates = validatorCandidates.slice(maxValidatorNumber, maxValidatorNumber * 2);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress, roninGovernanceAdminAddress } =
      await initTest('CreditScore')({
        trustedOrganizations: [governor].map((v) => ({
          consensusAddr: v.address,
          governor: v.address,
          bridgeVoter: v.address,
          weight: 100,
          addedBlock: 0,
        })),
        gainCreditScore,
        maxCreditScore,
        bailOutCostMultiplier,
        minValidatorBalance,
        maxValidatorNumber,
        numberOfBlocksInEpoch,
        minOffset,
        misdemeanorThreshold,
        felonyThreshold,
        slashFelonyAmount,
      });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetOverridePrecompile__factory.connect(validatorContractAddress, deployer);
    slashContract = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetOverridePrecompile__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);

    mockSlashLogic = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashLogic.deployed();
    await governanceAdminInterface.upgrade(slashContractAddress, mockSlashLogic.address);

    for (let i = 0; i < 2; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
          candidateAdmins[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          1,
          { value: minValidatorBalance.mul(2).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    localEpochController = new EpochController(minOffset, numberOfBlocksInEpoch);
    await localEpochController.mineToBeforeEndOfEpoch();
    await validatorContract.connect(coinbase).wrapUpEpoch();
    expect(await validatorContract.getValidators()).eql(validatorCandidates.slice(0, 2).map((_) => _.address));
    expect(await validatorContract.getBlockProducers()).eql(validatorCandidates.slice(0, 2).map((_) => _.address));

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
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[1].address]);
      await slashContract.connect(validatorCandidates[1]).slash(validatorCandidates[0].address);
      localIndicatorController.increaseAt(1);
      await endPeriodAndWrapUpAndResetIndicators();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore - 1);
      await validateScoreAt(0);
    });
    it('Should the score updated correctly, case: max score (N), in jail (y), unavailability (N)', async () => {
      await slashUntilValidatorTier(1, 0, 2);
      await wrapUpEpoch();
      await endPeriodAndWrapUpAndResetIndicators();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, 0);
      await validateScoreAt(0);

      let _jailLeft = await validatorContract.jailedTimeLeft(validatorCandidates[0].address);
      network.provider.send('hardhat_mine', [_jailLeft.blockLeft_.toHexString(), '0x0']);
    });
    it('Should the score updated correctly, case: max score (y), in jail (N), unavailability (N)', async () => {
      for (let i = 0; i < maxCreditScore / gainCreditScore + 1; i++) {
        await endPeriodAndWrapUpAndResetIndicators();
        localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
        await validateScoreAt(0);
      }
    });
  });

  describe('Bail out test', async () => {
    describe('Sanity check', async () => {
      it('Should the non admin candidate cannot call the bail out function', async () => {});
      it('Should the consensus address must be a candidate', async () => {});
    });

    describe('Bailing out from a to-be-in-jail validator', async () => {
      it('Should the bailing out cost subtracted correctly', async () => {});
      it('Should the indicator get reset', async () => {});
      it('Should the rewards of the validator before the bailout get removed', async () => {});
      it('Should the rewards of the validator after the bailout get cut in half', async () => {});
    });

    describe('Bailing out from a validator but non-block-producer', async () => {});

    describe('Bailing out from a kicked validator', async () => {});
    describe('Bailing out from a validator that has been bailed out previously', async () => {
      it('Should the bailed-out-validator not be able to bail out second time in the same period', async () => {});
      it('Should the bailed-out-validator be able to bail out in the next periods', async () => {});
    });
  });
});
