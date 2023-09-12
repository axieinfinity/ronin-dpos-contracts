import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { MockSorting, MockSorting__factory } from '../../../src/types';

let quickSortContract: MockSorting;

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];

const stats: { items: number; gasUsed: string }[] = [];

const runSortWithNRecords = async (numOfRecords: number) => {
  const balances = [];
  const mapV = new Map<number, boolean>();
  for (let i = 0; i < numOfRecords; ++i) {
    let value = 0;
    do {
      value = Math.floor(Math.random() * numOfRecords * 10_000);
    } while (!!mapV.get(value));
    mapV.set(value, true);
    balances.push({
      address: signers[i].address,
      value,
    });
  }

  balances.sort((a, b) => (a.value < b.value ? 1 : -1));

  const gasUsed = await quickSortContract.estimateGas.sortAddressesAndValues(
    balances.map((_) => _.address),
    balances.map((_) => _.value)
  );

  const sorted = await quickSortContract.sortAddressesAndValues(
    balances.map((_) => _.address),
    balances.map((_) => _.value)
  );

  expect(sorted).deep.equal(balances.map((_) => _.address));
  return gasUsed.toString();
};

describe.skip('Quick sort test', () => {
  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();
    quickSortContract = await new MockSorting__factory(deployer).deploy();
  });

  after(() => {
    console.table(stats);
  });

  for (let i = 1; i < 100; i++) {
    i % 10 == 9 &&
      it(`Should sort correctly on ${i} records`, async () => {
        stats.push({ items: i, gasUsed: await runSortWithNRecords(i) });
      });
  }
});
