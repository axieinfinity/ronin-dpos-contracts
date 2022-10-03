import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';

import {
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  MockSlashIndicatorExtended__factory,
  MockSlashIndicatorExtended,
  RoninTrustedOrganization__factory,
  RoninTrustedOrganization,
} from '../../src/types';
import { GovernanceAdminInterface, initTest } from '../helpers/fixture';

let validatorContract: MockRoninValidatorSetExtended;
let slashIndicator: MockSlashIndicatorExtended;
let governanceAdmin: GovernanceAdminInterface;
let roninTrustedOrganization: RoninTrustedOrganization;

let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const slashFelonyAmount = 100;
const maxValidatorNumber = 7;
const maxPrioritizedValidatorNumber = 4;
const maxValidatorCandidate = 100;

const setPriorityStatus = async (addrs: Address[], statuses: boolean[]) => {
  const arr = statuses.map((stt, i) => ({ address: addrs[i], stt }));
  const addingTrustedOrgs = arr.filter(({ stt }) => stt).map(({ address }) => address);
  const removingTrustedOrgs = arr.filter(({ stt }) => !stt).map(({ address }) => address);
  await governanceAdmin.functionDelegateCall(
    roninTrustedOrganization.address,
    roninTrustedOrganization.interface.encodeFunctionData('addTrustedOrganizations', [addingTrustedOrgs])
  );
  await governanceAdmin.functionDelegateCall(
    roninTrustedOrganization.address,
    roninTrustedOrganization.interface.encodeFunctionData('removeTrustedOrganizations', [removingTrustedOrgs])
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
    [deployer, governor, ...validatorCandidates] = await ethers.getSigners();
    governanceAdmin = new GovernanceAdminInterface(governor);

    const { slashContractAddress, validatorContractAddress, roninTrustedOrganizationAddress } = await initTest(
      'RoninValidatorSet-ArrangeValidators'
    )({
      governanceAdmin: governor.address,
      maxValidatorNumber,
      maxValidatorCandidate,
      maxPrioritizedValidatorNumber,
      slashFelonyAmount,
    });

    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    roninTrustedOrganization = RoninTrustedOrganization__factory.connect(roninTrustedOrganizationAddress, deployer);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdmin.upgrade(validatorContract.address, mockValidatorLogic.address);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdmin.upgrade(slashIndicator.address, mockSlashIndicator.address);
  });

  describe('Update priority list', async () => {
    it('Should be able to add new prioritized validators', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(true);

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to remove prioritized validators', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(false);

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) > num(remove)', async () => {
      let addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      let statuses = new Array(10).fill(true);
      await setPriorityStatus(addrs, statuses);

      addrs = validatorCandidates.slice(4, 7).map((_) => _.address);
      statuses = new Array(3).fill(false);
      addrs.push(...validatorCandidates.slice(10, 15).map((_) => _.address));
      statuses.push(...new Array(5).fill(true));

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) < num(remove)', async () => {
      let addrs = validatorCandidates.slice(0, 15).map((_) => _.address);
      let statuses = new Array(15).fill(false);
      await setPriorityStatus(addrs, statuses);

      addrs = validatorCandidates.slice(0, 10).map((_) => _.address);
      statuses = new Array(10).fill(true);
      await setPriorityStatus(addrs, statuses);

      addrs = validatorCandidates.slice(1, 8).map((_) => _.address);
      statuses = new Array(7).fill(false);
      addrs.push(...validatorCandidates.slice(10, 14).map((_) => _.address));
      statuses.push(...new Array(4).fill(true));
      await setPriorityStatus(addrs, statuses);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
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
      expect(outputValidators).eql(expectingValidatorAddrs);
    });
  });
});
