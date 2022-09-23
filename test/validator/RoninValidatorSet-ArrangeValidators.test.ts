import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';

import {
  Staking,
  MockRoninValidatorSetExtends,
  MockRoninValidatorSetExtends__factory,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
  MockSlashIndicator,
  MockSlashIndicator__factory,
  StakingVesting__factory,
  Maintenance__factory,
} from '../../src/types';
import { Address } from 'hardhat-deploy/dist/types';

let validatorContract: MockRoninValidatorSetExtends;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicator;

let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const slashFelonyAmount = 100;
const slashDoubleSignAmount = 1000;

const maxValidatorNumber = 7;
const maxPrioritizedValidatorNumber = 4;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

const maxValidatorCandidate = 100;
const minValidatorBalance = BigNumber.from(2);

const bonusPerBlock = BigNumber.from(1);
const topUpAmount = BigNumber.from(10000);

const setPriorityStatus = async (addrs: Address[], statuses: boolean[]) => {
  return TransparentUpgradeableProxyV2__factory.connect(validatorContract.address, proxyAdmin).functionDelegateCall(
    validatorContract.interface.encodeFunctionData('setPrioritizedAddresses', [addrs, statuses])
  );
};

const setPriorityStatusForMany = async (validators: SignerWithAddress[], status: boolean) => {
  if (validators.length == 0) {
    return;
  }
  let addrs = validators.map((_) => _.address);
  let statuses = new Array(validators.length).fill(status);
  await setPriorityStatus(addrs, statuses);
};

const setPriorityStatusByIndexes = async (indexes: number[], statuses: boolean[]) => {
  expect(indexes.length, 'invalid input for setPriorityStatusByIndex').eq(statuses.length);
  let addrs = indexes.filter((_, j) => statuses[j]).map((i) => validatorCandidates[i].address);
  statuses = statuses.filter((s) => s == true);

  await setPriorityStatus(addrs, statuses);
};

const sortArrayByBoolean = (indexes: number[], statuses: boolean[]) => {
  return indexes.sort((a, b) => {
    if (statuses[indexes.indexOf(a)] && !statuses[indexes.indexOf(b)]) return -1;
    if (!statuses[indexes.indexOf(a)] && statuses[indexes.indexOf(b)]) return 1;
    return 0;
  });
};

describe('Ronin Validator Set test -- Arrange validators', () => {
  before(async () => {
    [deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();

    const scheduleMaintenance = await new Maintenance__factory(deployer).deploy();
    const nonce = await deployer.getTransactionCount();
    const roninValidatorSetAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 4 });
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 6 });

    ///
    /// Deploy staking mock contract
    ///

    const stakingVestingLogic = await new StakingVesting__factory(deployer).deploy();
    const stakingVesting = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      stakingVestingLogic.address,
      proxyAdmin.address,
      stakingVestingLogic.interface.encodeFunctionData('initialize', [bonusPerBlock, roninValidatorSetAddr]),
      { value: topUpAmount }
    );

    ///
    /// Deploy slash indicator contract
    ///

    slashIndicator = await new MockSlashIndicator__factory(deployer).deploy(
      roninValidatorSetAddr,
      slashFelonyAmount,
      slashDoubleSignAmount
    );
    await slashIndicator.deployed();

    ///
    /// Deploy validator mock contract
    ///

    const validatorLogicContract = await new MockRoninValidatorSetExtends__factory(deployer).deploy();
    await validatorLogicContract.deployed();

    const validatorProxyContract = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      validatorLogicContract.address,
      proxyAdmin.address,
      validatorLogicContract.interface.encodeFunctionData('initialize', [
        slashIndicator.address,
        stakingContractAddr,
        stakingVesting.address,
        scheduleMaintenance.address,
        maxValidatorNumber,
        maxValidatorCandidate,
        maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch,
        numberOfEpochsInPeriod,
      ])
    );
    await validatorProxyContract.deployed();
    validatorContract = MockRoninValidatorSetExtends__factory.connect(validatorProxyContract.address, deployer);

    ///
    /// Deploy staking contract
    ///

    const stakingLogicContract = await new Staking__factory(deployer).deploy();
    await stakingLogicContract.deployed();

    const stakingProxyContract = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      stakingLogicContract.address,
      proxyAdmin.address,
      stakingLogicContract.interface.encodeFunctionData('initialize', [roninValidatorSetAddr, minValidatorBalance])
    );
    await stakingProxyContract.deployed();
    stakingContract = Staking__factory.connect(stakingProxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase(), 'wrong ronin validator set contract address').eq(
      validatorContract.address.toLowerCase()
    );
    expect(stakingContractAddr.toLowerCase(), 'wrong staking contract address').eq(
      stakingContract.address.toLowerCase()
    );
  });

  describe('ValidatorSetContract configuration', async () => {
    it('Should config the maxValidatorNumber correctly', async () => {
      let _maxValidatorNumber = await validatorContract.maxValidatorNumber();
      expect(_maxValidatorNumber).to.eq(maxValidatorNumber);
    });

    it('Should config the maxPrioritizedValidatorNumber correctly', async () => {
      let _maxPrioritizedValidatorNumber = await validatorContract.maxPrioritizedValidatorNumber();
      expect(_maxPrioritizedValidatorNumber).to.eq(maxPrioritizedValidatorNumber);
    });
  });

  describe('Update priority list', async () => {
    it('Should be able to add new prioritized validators', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(true);

      let tx = await setPriorityStatus(addrs, statuses);

      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);
    });

    it('Should be able to remove prioritized validators', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(false);

      let tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) > num(remove)', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(true);
      let tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);

      addrs = validatorCandidates.slice(4, 7).map((_) => _.address);
      statuses = new Array(3).fill(false);
      addrs.push(...validatorCandidates.slice(10, 15).map((_) => _.address));
      statuses.push(...new Array(5).fill(true));

      tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) < num(remove)', async () => {
      let addrs = validatorCandidates.slice(0, 15).map((_) => _.address);
      let statuses = new Array(15).fill(false);
      let tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);

      addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      statuses = new Array(10).fill(true);
      tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);

      addrs = validatorCandidates.slice(1, 8).map((_) => _.address);
      statuses = new Array(7).fill(false);
      addrs.push(...validatorCandidates.slice(10, 14).map((_) => _.address));
      statuses.push(...new Array(4).fill(true));
      tx = await setPriorityStatus(addrs, statuses);
      await RoninValidatorSet.expects.emitAddressesPriorityStatusUpdatedEvent(tx, addrs, statuses);
    });
  });

  describe('Arrange validators test', async () => {
    const maxRegularValidatorNumber = maxValidatorNumber - maxPrioritizedValidatorNumber;

    beforeEach(async () => {
      let validators = validatorCandidates.slice(0, 15);
      await setPriorityStatusForMany(validators, false);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        actualPrioritizedNumber + actualRegularNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber - 1;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, actualRegularNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        actualPrioritizedNumber + actualRegularNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let spareSlotNumber = 2;
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber - spareSlotNumber;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
        ...prioritizedValidators.slice(maxPrioritizedValidatorNumber, maxPrioritizedValidatorNumber + spareSlotNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - 1;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, actualPrioritizedNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        actualPrioritizedNumber + actualRegularNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let spareSlotNumber = 2;
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - spareSlotNumber;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
        ...regularValidators.slice(maxRegularValidatorNumber, maxRegularValidatorNumber + spareSlotNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - 2;
      let actualRegularNumber = maxRegularValidatorNumber - 2;

      let prioritizedValidators = validatorCandidates.slice(0, actualPrioritizedNumber);
      let regularValidators = validatorCandidates.slice(
        actualPrioritizedNumber,
        actualPrioritizedNumber + actualRegularNumber
      );

      await setPriorityStatusForMany(prioritizedValidators, true);
      await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators].map((_) => _.address);
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, actualPrioritizedNumber),
        ...regularValidators.slice(0, actualRegularNumber),
      ].map((_) => _.address);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        actualPrioritizedNumber + actualRegularNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });
  });

  describe('Arrange shuffled validators test', async () => {
    beforeEach(async () => {
      let validators = validatorCandidates.slice(0, 15);
      await setPriorityStatusForMany(validators, false);
    });

    it('Shuffled: Actual(prioritized) == MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      // prettier-ignore
      let indexes = [0, 1, 2, 3, 4, 5, 6];
      let statuses = [true, false, true, true, false, true, false];

      await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = sortArrayByBoolean(indexes, statuses);
      let expectingValidatorAddrs = sortedIndexes.map((i) => validatorCandidates[i].address);

      let inputValidatorAddrs = indexes.map((i) => validatorCandidates[i].address);
      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,

        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Shuffled: Actual(prioritized) >  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      // prettier-ignore
      let indexes = [0, 1, 2, 3, 4, 5, 6];
      let statuses = [true, false, true, true, false, true, true];

      await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = [0, 2, 3, 5, 1, 4, 6];
      let expectingValidatorAddrs = sortedIndexes.map((i) => validatorCandidates[i].address);

      let inputValidatorAddrs = indexes.map((i) => validatorCandidates[i].address);
      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,

        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });

    it('Shuffled: Actual(prioritized) <  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      // prettier-ignore
      let indexes = [0, 1, 2, 3, 4, 5, 6, 7];
      let statuses = [true, false, false, false, false, true, true, false];

      await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = sortArrayByBoolean(indexes, statuses);
      let expectingValidatorAddrs = sortedIndexes
        .map((i) => validatorCandidates[i].address)
        .slice(0, maxValidatorNumber);

      let inputValidatorAddrs = indexes.map((i) => validatorCandidates[i].address).slice(0, maxValidatorNumber);
      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        maxValidatorNumber
      );
      await expect(outputValidators).eql(expectingValidatorAddrs);
    });
  });
});
