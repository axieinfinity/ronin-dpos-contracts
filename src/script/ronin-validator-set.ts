import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from '../utils';
import { RoninValidatorSet__factory } from '../types';

const contractInterface = RoninValidatorSet__factory.createInterface();

export const expects = {
  emitRewardDeprecatedEvent: async function (
    tx: ContractTransaction,
    expectedCoinbaseAddr: string,
    expectedDeprecatedReward: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'RewardDeprecated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectedCoinbaseAddr);
        expect(event.args[1], 'invalid reward').eq(expectedDeprecatedReward);
      },
      1
    );
  },

  emitBlockRewardSubmittedEvent: async function (
    tx: ContractTransaction,
    expectedCoinbaseAddr: string,
    expectedDeprecatedReward: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'BlockRewardSubmitted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectedCoinbaseAddr);
        expect(event.args[1], 'invalid reward').eq(expectedDeprecatedReward);
      },
      1
    );
  },

  emitValidatorSlashedEvent: async function (
    tx: ContractTransaction,
    expectedValidatorAddr: string,
    expectedJailedUntil: BigNumberish,
    expectedDeductedStakingAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'ValidatorSlashed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectedValidatorAddr);
        expect(event.args[1], 'invalid jailed until').eq(expectedJailedUntil);
        expect(event.args[2], 'invalid deducted staking amount').eq(expectedDeductedStakingAmount);
      },
      1
    );
  },

  emitMiningRewardDistributedEvent: async function (
    tx: ContractTransaction,
    expectedCoinbaseAddr: string,
    expectedAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'MiningRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectedCoinbaseAddr);
        expect(event.args[1], 'invalid amount').eq(expectedAmount);
      },
      1
    );
  },

  emitStakingRewardDistributedEvent: async function (tx: ContractTransaction, expectedAmount: BigNumberish) {
    await expectEvent(
      contractInterface,
      'StakingRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid deprecated reward').eq(expectedAmount);
      },
      1
    );
  },

  emitValidatorSetUpdatedEvent: async function (tx: ContractTransaction, expectedValidators: string[]) {
    await expectEvent(
      contractInterface,
      'ValidatorSetUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator set').have.deep.members(expectedValidators);
      },
      1
    );
  },
};
