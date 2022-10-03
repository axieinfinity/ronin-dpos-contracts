import { BigNumber } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockSlashIndicatorExtended,
  MockSlashIndicatorExtended__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  Staking,
  Staking__factory,
} from '../../src/types';
import { BlockHeaderStruct } from '../../src/types/ISlashIndicator';
import { SlashType } from '../../src/script/slash-indicator';
import { GovernanceAdminInterface, initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';

let slashContract: MockSlashIndicatorExtended;
let mockSlashLogic: MockSlashIndicatorExtended;
let stakingContract: Staking;
let governanceAdmin: GovernanceAdminInterface;

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
const numberOfEpochsInPeriod = 48;
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

const generateDefaultBlockHeader = (blockHeight: number): BlockHeaderStruct => {
  return {
    parentHash: ethers.constants.HashZero,
    ommersHash: ethers.constants.HashZero,
    beneficiary: ethers.constants.AddressZero,
    stateRoot: ethers.constants.HashZero,
    transactionsRoot: ethers.constants.HashZero,
    receiptsRoot: ethers.constants.HashZero,
    logsBloom: new Array(256).fill(ethers.constants.HashZero),
    difficulty: 1,
    number: blockHeight,
    gasLimit: 1,
    gasUsed: 1,
    timestamp: 1,
    extraData: ethers.constants.HashZero,
    mixHash: ethers.constants.HashZero,
    nonce: 1,
  };
};

describe('Slash indicator test', () => {
  before(async () => {
    [deployer, coinbase, governor, vagabond, ...validatorCandidates] = await ethers.getSigners();
    governanceAdmin = new GovernanceAdminInterface(governor);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress } = await initTest('SlashIndicator')(
      {
        governanceAdmin: governor.address,
        misdemeanorThreshold,
        felonyThreshold,
        maxValidatorNumber,
        maxValidatorCandidate,
        numberOfBlocksInEpoch,
        numberOfEpochsInPeriod,
        minValidatorBalance,
        slashFelonyAmount,
        slashDoubleSignAmount,
      }
    );

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = RoninValidatorSet__factory.connect(validatorContractAddress, deployer);
    slashContract = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);

    mockSlashLogic = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashLogic.deployed();
    await governanceAdmin.upgrade(slashContractAddress, mockSlashLogic.address);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          1,
          { value: minValidatorBalance.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    await network.provider.send('hardhat_mine', [
      ethers.utils.hexStripZeros(BigNumber.from(numberOfBlocksInEpoch * numberOfEpochsInPeriod).toHexString()),
    ]);

    localEpochController = new EpochController(minOffset, numberOfBlocksInEpoch, numberOfEpochsInPeriod);
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
        await expect(slashContract.connect(vagabond).slash(validatorCandidates[0].address)).to.revertedWith(
          'SlashIndicator: method caller must be coinbase'
        );
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slash(validatorCandidates[slasheeIdx].address);
        await expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
        setLocalCounterForValidatorAt(slasheeIdx, 1);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        const slasherIdx = 0;
        await slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasherIdx].address);

        resetLocalCounterForValidatorAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasheeIdx].address);
        let tx = slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasheeIdx].address);
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
        await slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasheeIdx1].address);
        let tx = slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasheeIdx2].address);
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
            .slash(validatorCandidates[slasheeIdx].address);
        }

        let _period = await localEpochController.currentPeriod();
        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.MISDEMEANOR, _period);
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
          .slash(validatorCandidates[slasheeIdx].address);
        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        await expect(tx).not.to.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should sync with validator set for felony (slash tier-2)', async () => {
        let tx;
        const slasherIdx = 0;
        const slasheeIdx = 4;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        let _period = await localEpochController.currentPeriod();

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await slashContract
            .connect(validatorCandidates[slasherIdx])
            .slash(validatorCandidates[slasheeIdx].address);

          if (i == misdemeanorThreshold - 1) {
            await expect(tx)
              .to.emit(slashContract, 'UnavailabilitySlashed')
              .withArgs(validatorCandidates[slasheeIdx].address, SlashType.MISDEMEANOR, _period);
          }
        }

        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.FELONY, _period);
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
          .slash(validatorCandidates[slasheeIdx].address);
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
          await slashContract.connect(validatorCandidates[slasherIdx]).slash(validatorCandidates[slasheeIdx].address);
        }

        setLocalCounterForValidatorAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await localEpochController.mineToBeginOfNewPeriod();

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
              .slash(validatorCandidates[slasheeIdxs[j]].address);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          setLocalCounterForValidatorAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await localEpochController.mineToBeginOfNewPeriod();

        for (let j = 0; j < slasheeIdxs.length; j++) {
          resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });

    describe('Double signing slash', async () => {
      let header1: BlockHeaderStruct;
      let header2: BlockHeaderStruct;

      before(async () => {
        await network.provider.send('hardhat_mine', [doubleSigningConstrainBlocks.toHexString()]);
      });

      it('Should not be able to slash themselves', async () => {
        const slasherIdx = 0;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].address]);

        let nextBlockHeight = await network.provider.send('eth_blockNumber');

        header1 = generateDefaultBlockHeader(nextBlockHeight - 1);
        header2 = generateDefaultBlockHeader(nextBlockHeight - 1);

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashDoubleSign(validatorCandidates[slasherIdx].address, header1, header2);

        await expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should not be able to slash with mismatched parent hash', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;
        let nextBlockHeight = await network.provider.send('eth_blockNumber');

        header1 = generateDefaultBlockHeader(nextBlockHeight - 1);
        header2 = generateDefaultBlockHeader(nextBlockHeight - 1);

        header1.parentHash = ethers.constants.HashZero.slice(0, -1) + '1';

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashDoubleSign(validatorCandidates[slasheeIdx].address, header1, header2);

        await expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should be able to slash validator with double signing', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;
        let nextBlockHeight = await network.provider.send('eth_blockNumber');

        header1 = generateDefaultBlockHeader(nextBlockHeight - 1);
        header2 = generateDefaultBlockHeader(nextBlockHeight - 1);

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx])
          .slashDoubleSign(validatorCandidates[slasheeIdx].address, header1, header2);

        let _period = await localEpochController.currentPeriod();

        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(validatorCandidates[slasheeIdx].address, SlashType.DOUBLE_SIGNING, _period);
      });
    });
  });
});
