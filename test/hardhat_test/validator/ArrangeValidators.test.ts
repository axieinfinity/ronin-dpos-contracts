import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';

import {
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  MockSlashIndicatorExtended__factory,
  MockSlashIndicatorExtended,
  RoninTrustedOrganization__factory,
  RoninTrustedOrganization,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
} from '../../../src/types';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';

let validatorContract: MockRoninValidatorSetExtended;
let slashIndicator: MockSlashIndicatorExtended;
let roninTrustedOrganization: RoninTrustedOrganization;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: Address[];

const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 7;
const maxPrioritizedValidatorNumber = 4;
const maxValidatorCandidate = 100;
const defaultTrustedWeight = BigNumber.from(100);

const setPriorityStatus = async (addrs: Address[], statuses: boolean[]): Promise<BigNumberish[]> => {
  const arr = statuses.map((stt, i) => ({ address: addrs[i], stt }));
  const addingTrustedOrgs = arr.filter(({ stt }) => stt).map(({ address }) => address);
  const removingTrustedOrgs = arr.filter(({ stt }) => !stt).map(({ address }) => address);
  if (addingTrustedOrgs.length > 0) {
    await governanceAdminInterface.functionDelegateCalls(
      addingTrustedOrgs.map(() => roninTrustedOrganization.address),
      addingTrustedOrgs.map((v) =>
        roninTrustedOrganization.interface.encodeFunctionData('addTrustedOrganizations', [
          [{ consensusAddr: v, governor: v, bridgeVoter: v, weight: 100, addedBlock: 0 }],
        ])
      )
    );
  }
  if (removingTrustedOrgs.length > 0) {
    await governanceAdminInterface.functionDelegateCalls(
      removingTrustedOrgs.map(() => roninTrustedOrganization.address),
      removingTrustedOrgs.map((v) =>
        roninTrustedOrganization.interface.encodeFunctionData('removeTrustedOrganizations', [[v]])
      )
    );
  }

  return statuses.map((stt) => (stt ? defaultTrustedWeight : 0));
};

const setPriorityStatusForMany = async (validators: Address[], status: boolean): Promise<BigNumberish[]> => {
  if (validators.length == 0) {
    return [];
  }
  let statuses = new Array(validators.length).fill(status);
  return await setPriorityStatus(validators, statuses);
};

const setPriorityStatusByIndexes = async (indexes: number[], statuses: boolean[]): Promise<BigNumberish[]> => {
  expect(indexes.length, 'invalid input for setPriorityStatusByIndex').eq(statuses.length);
  let addrs = indexes.map((i) => candidates[i]);

  return await setPriorityStatus(addrs, statuses);
};

const sortArrayByBoolean = (indexes: number[], statuses: boolean[]) => {
  return indexes.sort((a, b) => {
    if (statuses[indexes.indexOf(a)] && !statuses[indexes.indexOf(b)]) return -1;
    if (!statuses[indexes.indexOf(a)] && statuses[indexes.indexOf(b)]) return 1;
    return 0;
  });
};

describe('Arrange validators', () => {
  before(async () => {
    [deployer, governor, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));

    candidates = Array.from({ length: maxValidatorCandidate }, (_, i) =>
      ethers.utils.hexZeroPad(ethers.utils.hexlify(i + 0x40), 20)
    );

    const {
      slashContractAddress,
      validatorContractAddress,
      roninTrustedOrganizationAddress,
      roninGovernanceAdminAddress,
    } = await initTest('ArrangeValidators')({
      slashIndicatorArguments: {
        unavailabilitySlashing: {
          slashAmountForUnavailabilityTier2Threshold,
        },
      },
      roninValidatorSetArguments: {
        maxValidatorCandidate,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
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
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    roninTrustedOrganization = RoninTrustedOrganization__factory.connect(roninTrustedOrganizationAddress, deployer);
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

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);
  });

  describe('Update priority list', async () => {
    it('Should be able to add new prioritized validators', async () => {
      let addrs = candidates.slice(0, 10);
      let statuses = new Array(10).fill(true);

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to remove prioritized validators', async () => {
      let addrs = candidates.slice(0, 10);
      let statuses = new Array(10).fill(false);

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) > num(remove)', async () => {
      let addrs = candidates.slice(0, 10);
      let statuses = new Array(10).fill(true);
      await setPriorityStatus(addrs, statuses);

      addrs = candidates.slice(4, 7);
      statuses = new Array(3).fill(false);
      addrs.push(...candidates.slice(10, 15));
      statuses.push(...new Array(5).fill(true));

      await setPriorityStatus(addrs, statuses);
    });

    it('Should be able to add and remove prioritized validators: num(add) < num(remove)', async () => {
      let addrs = candidates.slice(0, 15);
      let statuses = new Array(15).fill(false);
      await setPriorityStatus(addrs, statuses);

      addrs = candidates.slice(0, 10);
      statuses = new Array(10).fill(true);
      await setPriorityStatus(addrs, statuses);

      addrs = candidates.slice(1, 8);
      statuses = new Array(7).fill(false);
      addrs.push(...candidates.slice(10, 14));
      statuses.push(...new Array(4).fill(true));
      await setPriorityStatus(addrs, statuses);
    });
  });

  describe('Arrange validators test', async () => {
    const maxRegularValidatorNumber = maxValidatorNumber - maxPrioritizedValidatorNumber;

    beforeEach(async () => {
      let validators = candidates.slice(0, 15);
      await setPriorityStatusForMany(validators, false);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        actualPrioritizedNumber + actualRegularNumber,
        maxPrioritizedValidatorNumber
      );

      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber;
      let actualRegularNumber = maxRegularValidatorNumber - 1;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, actualRegularNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        actualPrioritizedNumber + actualRegularNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let spareSlotNumber = 2;
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber + 10;
      let actualRegularNumber = maxRegularValidatorNumber - spareSlotNumber;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
        ...prioritizedValidators.slice(maxPrioritizedValidatorNumber, maxPrioritizedValidatorNumber + spareSlotNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - 1;
      let actualRegularNumber = maxRegularValidatorNumber;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, actualPrioritizedNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        actualPrioritizedNumber + actualRegularNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let spareSlotNumber = 2;
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - spareSlotNumber;
      let actualRegularNumber = maxRegularValidatorNumber + 10;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, maxPrioritizedValidatorNumber),
        ...regularValidators.slice(0, maxRegularValidatorNumber),
        ...regularValidators.slice(maxRegularValidatorNumber, maxRegularValidatorNumber + spareSlotNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let actualPrioritizedNumber = maxPrioritizedValidatorNumber - 2;
      let actualRegularNumber = maxRegularValidatorNumber - 2;

      let prioritizedValidators = candidates.slice(0, actualPrioritizedNumber);
      let regularValidators = candidates.slice(actualPrioritizedNumber, actualPrioritizedNumber + actualRegularNumber);

      let prioritizedWeights = await setPriorityStatusForMany(prioritizedValidators, true);
      let regularWeights = await setPriorityStatusForMany(regularValidators, false);

      let inputValidatorAddrs = [...regularValidators, ...prioritizedValidators];
      let inputTrustedWeights = [...regularWeights, ...prioritizedWeights];
      let expectingValidatorAddrs = [
        ...prioritizedValidators.slice(0, actualPrioritizedNumber),
        ...regularValidators.slice(0, actualRegularNumber),
      ];

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        actualPrioritizedNumber + actualRegularNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });
  });

  describe('Arrange shuffled validators test', async () => {
    beforeEach(async () => {
      let validators = candidates.slice(0, 15);
      await setPriorityStatusForMany(validators, false);
    });

    it('Shuffled: Actual(prioritized) == MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let indexes = [0, 1, 2, 3, 4, 5, 6];
      let statuses = [true, false, true, true, false, true, false];

      let inputTrustedWeights = await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = sortArrayByBoolean([...indexes], statuses);
      let expectingValidatorAddrs = sortedIndexes.map((i) => candidates[i]);

      let inputValidatorAddrs = indexes.map((i) => candidates[i]);

      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Shuffled: Actual(prioritized) >  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let indexes = [0, 1, 2, 3, 4, 5, 6];
      let statuses = [true, false, true, true, false, true, true];

      let inputTrustedWeights = await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = [0, 2, 3, 5, 1, 4, 6];
      let expectingValidatorAddrs = sortedIndexes.map((i) => candidates[i]);

      let inputValidatorAddrs = indexes.map((i) => candidates[i]);
      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });

    it('Shuffled: Actual(prioritized) <  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let indexes = [0, 1, 2, 3, 4, 5, 6, 7];
      let statuses = [true, false, false, false, false, true, true, false];

      let inputTrustedWeights = await setPriorityStatusByIndexes(indexes, statuses);

      let sortedIndexes = sortArrayByBoolean([...indexes], statuses);
      let expectingValidatorAddrs = sortedIndexes.map((i) => candidates[i]).slice(0, maxValidatorNumber);

      let inputValidatorAddrs = indexes.map((i) => candidates[i]).slice(0, maxValidatorNumber);
      let outputValidators = await validatorContract.arrangeValidatorCandidates(
        inputValidatorAddrs,
        inputTrustedWeights,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber
      );
      expect(outputValidators).deep.equal(expectingValidatorAddrs);
    });
  });
});
