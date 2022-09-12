import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from '../utils';
import { Staking__factory } from '../types';

const contractInterface = Staking__factory.createInterface();

export const expects = {
  emitValidatorProposedEvent: async function (
    tx: ContractTransaction,
    expectedValidator: string,
    expectedAdmin: string,
    expectedIdx: BigNumberish,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'ValidatorProposed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectedValidator);
        expect(event.args[1], 'invalid validator').eq(expectedAdmin);
        expect(event.args[2], 'invalid index').eq(expectedIdx);
      },
      1
    );
  },

  emitStakedEvent: async function (tx: ContractTransaction, expectedValidator: string, expectedAmount: BigNumberish) {
    await expectEvent(
      contractInterface,
      'Staked',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectedValidator);
        expect(event.args[1], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitUnstakedEvent: async function (tx: ContractTransaction, expectedValidator: string, expectedAmount: BigNumberish) {
    await expectEvent(
      contractInterface,
      'Unstaked',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectedValidator);
        expect(event.args[1], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitValidatorRenounceRequestedEvent: async function (
    tx: ContractTransaction,
    expectedValidator: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'ValidatorRenounceRequested',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectedValidator);
        expect(event.args[1], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitValidatorRenounceFinalizedEvent: async function (
    tx: ContractTransaction,
    expectedValidator: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'ValidatorRenounceFinalized',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectedValidator);
        expect(event.args[1], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitDelegatedEvent: async function (
    tx: ContractTransaction,
    expectedDelegator: string,
    expectedValidator: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'Delegated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid delegator').eq(expectedDelegator);
        expect(event.args[1], 'invalid validator').eq(expectedValidator);
        expect(event.args[2], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitUndelegatedEvent: async function (
    tx: ContractTransaction,
    expectedDelegator: string,
    expectedValidator: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'Undelegated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid delegator').eq(expectedDelegator);
        expect(event.args[1], 'invalid validator').eq(expectedValidator);
        expect(event.args[2], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitSettledPoolsUpdatedEvent: async function (
    tx: ContractTransaction,
    expectedPoolAddressList: string[],
    expectedAccumulatedRpsList: BigNumberish[]
  ) {
    await expectEvent(
      contractInterface,
      'SettledPoolsUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid pool address list').eql(expectedPoolAddressList);
        expect(event.args[1], 'invalid accumulated rps list').eql(expectedAccumulatedRpsList);
      },
      1
    );
  },

  emitPendingPoolUpdatedEvent: async function (
    tx: ContractTransaction,
    expectedPoolAddress: string,
    expectedAccumulatedRps: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'PendingPoolUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid pool address').eq(expectedPoolAddress);
        expect(event.args[1], 'invalid accumulated rps').eq(expectedAccumulatedRps);
      },
      1
    );
  },

  emitSettledRewardUpdatedEvent: async function (
    tx: ContractTransaction,
    expectedPoolAddress: string,
    expectedUser: string,
    expectedBalance: BigNumberish,
    expectedDebited: BigNumberish,
    expectedAccumulatedRps: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'SettledRewardUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid pool address').eq(expectedPoolAddress);
        expect(event.args[1], 'invalid user').eq(expectedUser);
        expect(event.args[2], 'invalid balance').eq(expectedBalance);
        expect(event.args[3], 'invalid debited').eq(expectedDebited);
        expect(event.args[4], 'invalid accumulated rps').eq(expectedAccumulatedRps);
      },
      1
    );
  },

  emitPendingRewardUpdatedEvent: async function (
    tx: ContractTransaction,
    expectedPoolAddress: string,
    expectedUser: string,
    expectedDebited: BigNumberish,
    expectedCredited: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'PendingRewardUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid pool address').eq(expectedPoolAddress);
        expect(event.args[1], 'invalid user').eq(expectedUser);
        expect(event.args[2], 'invalid debited').eq(expectedDebited);
        expect(event.args[3], 'invalid credited').eq(expectedCredited);
      },
      1
    );
  },

  emitRewardClaimedEvent: async function (
    tx: ContractTransaction,
    expectedPoolAddress: string,
    expectedUser: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'RewardClaimed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid pool address').eq(expectedPoolAddress);
        expect(event.args[1], 'invalid user').eq(expectedUser);
        expect(event.args[2], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },
};
