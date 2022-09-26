import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { RoninValidatorSet__factory } from '../../src/types';

const contractInterface = RoninValidatorSet__factory.createInterface();

export const expects = {
  emitRewardDeprecatedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingDeprecatedReward: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'RewardDeprecated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid reward').eq(expectingDeprecatedReward);
      },
      1
    );
  },

  emitBlockRewardSubmittedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingSubmittedReward: BigNumberish,
    expectingBonusReward: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'BlockRewardSubmitted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid submitted reward').eq(expectingSubmittedReward);
        expect(event.args[2], 'invalid bonus reward').eq(expectingBonusReward);
      },
      1
    );
  },

  emitMiningRewardDistributedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'MiningRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid amount').eq(expectingAmount);
      },
      1
    );
  },

  emitStakingRewardDistributedEvent: async function (tx: ContractTransaction, expectingAmount: BigNumberish) {
    await expectEvent(
      contractInterface,
      'StakingRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid distributing reward').eq(expectingAmount);
      },
      1
    );
  },

  emitValidatorSetUpdatedEvent: async function (tx: ContractTransaction, expectingValidators: string[]) {
    await expectEvent(
      contractInterface,
      'ValidatorSetUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator set').have.deep.members(expectingValidators);
      },
      1
    );
  },

  emitAddressesPriorityStatusUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingAddressList: string[],
    expectingPriorityStatusList: boolean[]
  ) {
    await expectEvent(
      contractInterface,
      'AddressesPriorityStatusUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid address list').eql(expectingAddressList);
        expect(event.args[1], 'invalid priority status list').eql(expectingPriorityStatusList);
      },
      1
    );
  },
};
