import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { Sorting, Sorting__factory, MockSorting, MockSorting__factory } from '../../src/types';

let quickSortLib: Sorting;
let quickSortContract: MockSorting;

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];

const runSortWithNRecords = async (numOfRecords: number) => {
  let balances = [];
  for (let i = 0; i < numOfRecords; ++i) {
    balances.push({
      address: signers[i].address,
      value: Math.floor(Math.random() * numOfRecords * 1000),
    });
  }

  balances.sort((a, b) => (a.value < b.value ? 1 : -1));

  let sorted = await quickSortContract.sortAddressesAndValues(
    balances.map((_) => _.address),
    balances.map((_) => _.value)
  );

  expect(sorted).eql(balances.map((_) => _.address));
};

describe('Quick sort', () => {
  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();
    quickSortLib = await new Sorting__factory(deployer).deploy();
    quickSortContract = await new MockSorting__factory(
      {
        'contracts/libraries/Sorting.sol:Sorting': quickSortLib.address,
      },
      deployer
    ).deploy();
  });

  describe('Sorting on sort(address[], uint[])', async () => {
    it('Should sort correctly on 10 records', async () => {
      await runSortWithNRecords(10);
    });

    it('Should sort correctly on 21 records', async () => {
      await runSortWithNRecords(21);
    });

    it('Should sort correctly on 50 records', async () => {
      await runSortWithNRecords(50);
    });

    it('Should sort correctly on 99 records', async () => {
      await runSortWithNRecords(99);
    });
  });
});
