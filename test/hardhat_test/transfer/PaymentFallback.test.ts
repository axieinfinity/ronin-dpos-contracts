import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPaymentFallback,
  MockPaymentFallbackExpensive,
  MockPaymentFallbackExpensive__factory,
  MockPaymentFallback__factory,
  MockTransfer,
  MockTransfer__factory,
} from '../../../src/types';
import { BigNumber } from 'ethers';

let senderContract: MockTransfer;
let receiverContract: MockPaymentFallback;
let receiverExpensiveContract: MockPaymentFallbackExpensive;

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];

describe('Payment fallback test', () => {
  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();
    senderContract = await new MockTransfer__factory(deployer).deploy({ value: 1000 });
    receiverContract = await new MockPaymentFallback__factory(deployer).deploy();
    receiverExpensiveContract = await new MockPaymentFallbackExpensive__factory(deployer).deploy();
  });
  describe('Receiver contract only emit one event in fallback', async () => {
    it('Should transfer successfully with 0 gas in addition', async () => {
      let value = 1;
      let gas = 0;
      await expect(senderContract.fooTransfer(receiverContract.address, value, gas))
        .emit(receiverContract, 'SafeReceived')
        .withArgs(senderContract.address, value);
    });
    it('Should transfer successfully with 2300 gas in addition', async () => {
      let value = 1;
      let gas = 2300;
      await expect(senderContract.fooTransfer(receiverContract.address, value, gas))
        .emit(receiverContract, 'SafeReceived')
        .withArgs(senderContract.address, value);
    });
    it('Should transfer successfully with 3500 gas in addition', async () => {
      let value = 1;
      let gas = 3500;
      await expect(senderContract.fooTransfer(receiverContract.address, value, gas))
        .emit(receiverContract, 'SafeReceived')
        .withArgs(senderContract.address, value);
    });
  });
  describe('Receiver contract only emit one event in fallback and set one storage in contract', async () => {
    it('Should transfer failed with 0 gas in addition', async () => {
      let value = 1;
      let gas = 0;
      let tx;
      await expect(
        async () => (tx = await senderContract.fooTransfer(receiverExpensiveContract.address, value, gas))
      ).changeEtherBalances([receiverExpensiveContract.address], [BigNumber.from(0)]);
      await expect(tx).not.emit(receiverExpensiveContract, 'SafeReceived');
    });
    it('Should transfer failed with 1000 gas in addition', async () => {
      let value = 1;
      let gas = 1000;
      let tx;
      await expect(
        async () => (tx = await senderContract.fooTransfer(receiverExpensiveContract.address, value, gas))
      ).changeEtherBalances([receiverExpensiveContract.address], [BigNumber.from(0)]);
      await expect(tx).not.emit(receiverExpensiveContract, 'SafeReceived');
    });
    it('Should transfer failed with 2300 gas in addition', async () => {
      let value = 1;
      let gas = 2300;
      let tx;
      await expect(
        async () => (tx = await senderContract.fooTransfer(receiverExpensiveContract.address, value, gas))
      ).changeEtherBalances([receiverExpensiveContract.address], [BigNumber.from(0)]);
      await expect(tx).not.emit(receiverExpensiveContract, 'SafeReceived');
    });
    it('Should transfer failed with 20000 gas in addition', async () => {
      let value = 1;
      let gas = 20000;
      let tx;
      await expect(
        async () => (tx = await senderContract.fooTransfer(receiverExpensiveContract.address, value, gas))
      ).changeEtherBalances([receiverExpensiveContract.address], [BigNumber.from(0)]);
      await expect(tx).not.emit(receiverExpensiveContract, 'SafeReceived');
    });
    it('Should transfer successfully with 26000 gas in addition', async () => {
      let value = 1;
      let gas = 26000;
      let tx;
      await expect(
        async () => (tx = await senderContract.fooTransfer(receiverExpensiveContract.address, value, gas))
      ).changeEtherBalances([receiverExpensiveContract.address], [BigNumber.from(1)]);
      await expect(tx).emit(receiverExpensiveContract, 'SafeReceived');
    });
  });
});
