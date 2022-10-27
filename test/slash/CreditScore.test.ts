import { BigNumber, BytesLike } from 'ethers';
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

const minValidatorBalance = BigNumber.from(100);
const maxValidatorNumber = 5;
const numberOfBlocksInEpoch = 600;
const minOffset = 200;

const endPeriodAndWrapUp = async (includingEpochsNum?: number) => {
  includingEpochsNum = includingEpochsNum ?? 1;
  for (let i = 0; i < includingEpochsNum; i++) {
    await localEpochController.mineToBeforeEndOfEpoch();
  }
  await EpochController.setTimestampToPeriodEnding();
  await validatorContract.connect(coinbase).wrapUpEpoch();
};

const validateScoreAt = async (idx: number) => {
  expect(await slashContract.getCreditScore(validatorCandidates[idx].address)).to.eq(localScoreController.getAt(idx));
};

describe('Credit score and bail out test', () => {
  before(async () => {
    [deployer, coinbase, governor, vagabond, ...validatorCandidates] = await ethers.getSigners();

    candidateAdmins = validatorCandidates.slice(maxValidatorNumber);
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

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
          candidateAdmins[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          1,
          { value: minValidatorBalance.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    localEpochController = new EpochController(minOffset, numberOfBlocksInEpoch);
    await localEpochController.mineToBeforeEndOfEpoch();
    await validatorContract.connect(coinbase).wrapUpEpoch();
    expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
    expect(await validatorContract.getBlockProducers()).eql(validatorCandidates.map((_) => _.address));

    localIndicatorController = new IndicatorController(validatorCandidates.length);
    localScoreController = new ScoreController(validatorCandidates.length);
  });

  describe('Counting credit score after each period', async () => {
    it('Should the score updated correctly, case: in jail (N), max score (N), unavailability (N)', async () => {
      await endPeriodAndWrapUp();
      localScoreController.increaseAtWithUpperbound(0, maxCreditScore, gainCreditScore);
      await validateScoreAt(0);
    });
    it('Should the score updated correctly, case: in jail (N), max score (N), unavailability (y)', async () => {});
    it('Should the score updated correctly, case: in jail (N), max score (y), unavailability (N)', async () => {});
    it('Should the score updated correctly, case: in jail (N), max score (y), unavailability (y)', async () => {});
    it('Should the score updated correctly, case: in jail (y), max score (N), unavailability (N)', async () => {});
    it('Should the score updated correctly, case: in jail (y), max score (N), unavailability (y)', async () => {});
    it('Should the score updated correctly, case: in jail (y), max score (y), unavailability (N)', async () => {});
    it('Should the score updated correctly, case: in jail (y), max score (y), unavailability (y)', async () => {});
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
