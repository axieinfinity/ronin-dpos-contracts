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
import { SlashType } from '../../src/script/slash-indicator';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
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
let validatorCandidates: SignerWithAddress[];
let localIndicators: number[];

let localEpochController: EpochController;

const misdemeanorThreshold = 5;
const felonyThreshold = 10;
const maxValidatorNumber = 21;
const maxValidatorCandidate = 50;
const numberOfBlocksInEpoch = 600;
const minValidatorBalance = BigNumber.from(100);

const slashFelonyAmount = BigNumber.from(2);
const slashDoubleSignAmount = BigNumber.from(5);

const minOffset = 200;
const doubleSigningConstrainBlocks = BigNumber.from(28800);

const increaseLocalCounterForValidatorAt = (idx: number, value?: number) => {
  value = value ?? 1;
  localIndicators[idx] += value;
};

const setLocalCounterForValidatorAt = (idx: number, value: number) => {
  localIndicators[idx] = value;
};

const resetLocalCounterForValidatorAt = (idx: number) => {
  localIndicators[idx] = 0;
};

const validateIndicatorAt = async (idx: number) => {
  expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[idx].address)).to.eq(
    localIndicators[idx]
  );
};

describe('Slash indicator test', () => {
  before(async () => {
    [deployer, coinbase, governor, vagabond, ...validatorCandidates] = await ethers.getSigners();

    const { slashContractAddress, stakingContractAddress, validatorContractAddress, roninGovernanceAdminAddress } =
      await initTest('SlashIndicator')({
        trustedOrganizations: [governor].map((v) => ({
          consensusAddr: v.address,
          governor: v.address,
          bridgeVoter: v.address,
          weight: 100,
          addedBlock: 0,
        })),
        misdemeanorThreshold,
        felonyThreshold,
        maxValidatorNumber,
        maxValidatorCandidate,
        numberOfBlocksInEpoch,
        minValidatorBalance,
        slashFelonyAmount,
        slashDoubleSignAmount,
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
          validatorCandidates[i].address,
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

    localIndicators = Array<number>(validatorCandidates.length).fill(0);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Single flow test', async () => {
    describe('Unauthorized test', async () => {
      it('Should non-coinbase cannot call slash', async () => {
        await expect(
          slashContract.connect(vagabond).slashUnavailability(validatorCandidates[0].address)
        ).to.revertedWith('SlashIndicator: method caller must be coinbase');
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx].address);
        await expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
        setLocalCounterForValidatorAt(slasheeIdx, 1);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        const slasherIdx = 0;
        await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasherIdx].address);

        resetLocalCounterForValidatorAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx].address);
        let tx = slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx].address);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not able to slash more than one validator in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx1 = 1;
        const slasheeIdx2 = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx1].address);
        let tx = slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx2].address);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        increaseLocalCounterForValidatorAt(slasheeIdx1);
        await validateIndicatorAt(slasheeIdx1);
        setLocalCounterForValidatorAt(slasheeIdx2, 1);
        await validateIndicatorAt(slasheeIdx1);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for misdemeanor (slash tier-1)', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        for (let i = 0; i < misdemeanorThreshold; i++) {
          tx = await slashContract
            .connect(validatorCandidates[slasherIdx])
            .slashUnavailability(validatorCandidates[slasheeIdx].address);
        }

        let period = await validatorContract.currentPeriod();
        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.MISDEMEANOR, period);
        setLocalCounterForValidatorAt(slasheeIdx, misdemeanorThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter is in between misdemeanor (tier-1) and felony (tier-2) thresholds', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx].address);
        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        await expect(tx).not.to.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should sync with validator set for felony (slash tier-2)', async () => {
        let tx;
        const slasherIdx = 0;
        const slasheeIdx = 4;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        let period = await validatorContract.currentPeriod();

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await slashContract
            .connect(validatorCandidates[slasherIdx])
            .slashUnavailability(validatorCandidates[slasheeIdx].address);

          if (i == misdemeanorThreshold - 1) {
            await expect(tx)
              .to.emit(slashContract, 'UnavailabilitySlashed')
              .withArgs(validatorCandidates[slasheeIdx].address, SlashType.MISDEMEANOR, period);
          }
        }

        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.FELONY, period);
        setLocalCounterForValidatorAt(slasheeIdx, felonyThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter exceeds felony threshold (tier-2) ', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashUnavailability(validatorCandidates[slasheeIdx].address);
        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        await expect(tx).not.to.emit(slashContract, 'UnavailabilitySlashed');
      });
    });

    describe('Resetting counter', async () => {
      it('Should the counter reset for one validator when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 5;
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          await slashContract
            .connect(validatorCandidates[slasherIdx])
            .slashUnavailability(validatorCandidates[slasheeIdx].address);
        }

        setLocalCounterForValidatorAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await EpochController.setTimestampToPeriodEnding();
        await localEpochController.mineToBeforeEndOfEpoch();
        await validatorContract.connect(validatorCandidates[slasherIdx]).wrapUpEpoch();

        resetLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should the counter reset for multiple validators when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdxs = [6, 7, 8, 9, 10];
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          for (let j = 0; j < slasheeIdxs.length; j++) {
            await slashContract
              .connect(validatorCandidates[slasherIdx])
              .slashUnavailability(validatorCandidates[slasheeIdxs[j]].address);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          setLocalCounterForValidatorAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await EpochController.setTimestampToPeriodEnding();
        await localEpochController.mineToBeforeEndOfEpoch();
        await validatorContract.connect(validatorCandidates[slasherIdx]).wrapUpEpoch();

        for (let j = 0; j < slasheeIdxs.length; j++) {
          resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });

    describe('Double signing slash', async () => {
      let header1: BytesLike;
      let header2: BytesLike;

      before(async () => {
        await network.provider.send('hardhat_mine', [doubleSigningConstrainBlocks.toHexString(), '0x0']);
      });

      it('Should not be able to slash themselves', async () => {
        const slasherIdx = 0;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashDoubleSign(validatorCandidates[slasherIdx].address, header1, header2);

        await expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should be able to slash validator with double signing', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;

        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashDoubleSign(validatorCandidates[slasheeIdx].address, header1, header2);

        let period = await validatorContract.currentPeriod();

        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.DOUBLE_SIGNING, period);
      });
    });
  });
});
