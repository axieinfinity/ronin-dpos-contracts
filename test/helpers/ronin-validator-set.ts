import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { RoninValidatorSet__factory } from '../../src/types';

const contractInterface = RoninValidatorSet__factory.createInterface();

export class EpochController {
  readonly minOffset: number;
  readonly numberOfBlocksInEpoch: number;

  constructor(minOffset: number, numberOfBlocksInEpoch: number) {
    this.minOffset = minOffset;
    this.numberOfBlocksInEpoch = numberOfBlocksInEpoch;
  }

  calculateStartOfEpoch(block: number): BigNumber {
    return BigNumber.from(
      Math.floor((block + this.minOffset) / this.numberOfBlocksInEpoch + 1) * this.numberOfBlocksInEpoch
    );
  }

  diffToEndEpoch(block: BigNumberish): BigNumber {
    return BigNumber.from(this.numberOfBlocksInEpoch).sub(BigNumber.from(block).mod(this.numberOfBlocksInEpoch)).sub(1);
  }

  calculateEndOfEpoch(block: BigNumberish): BigNumber {
    return BigNumber.from(block).add(this.diffToEndEpoch(block));
  }

  async mineToBeforeEndOfEpoch(includingEpochsNum?: BigNumberish) {
    let number = this.diffToEndEpoch(await ethers.provider.getBlockNumber()).sub(1);
    if (number.lt(0)) {
      number = number.add(this.numberOfBlocksInEpoch);
    }

    if (includingEpochsNum! > 1) {
      number = number.add(BigNumber.from(includingEpochsNum).sub(1).mul(this.numberOfBlocksInEpoch));
    }

    const numberHex = number.eq(0) ? '0x0' : ethers.utils.hexStripZeros(number.toHexString());
    return network.provider.send('hardhat_mine', [numberHex, '0x0']);
  }

  static async setTimestampToPeriodEnding(): Promise<void> {
    const currentDate = new Date();
    const currentTimestamp = currentDate.getTime();
    const nextDate = new Date(currentDate.setDate(currentDate.getDate() + 1));
    const nextBeginningDate = new Date(nextDate.getFullYear(), nextDate.getMonth(), nextDate.getDate());
    const nextBeginningDateTimestamp = nextBeginningDate.getTime();
    await network.provider.send('evm_increaseTime', [
      86400 + Math.floor((nextBeginningDateTimestamp - currentTimestamp) / 1000),
    ]);
  }

  async mineToBeginOfNewEpoch() {
    await this.mineToBeforeEndOfEpoch();
    return network.provider.send('hardhat_mine', ['0x2', '0x0']);
  }
}

export const expects = {
  emitBlockRewardSubmittedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingSubmittedReward: BigNumberish,
    expectingStakingVesting: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'BlockRewardSubmitted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid submitted reward').eq(expectingSubmittedReward);
        expect(event.args[2], 'invalid staking vesting').eq(expectingStakingVesting);
      },
      1
    );
  },

  emitMiningRewardDistributedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingRecipientAddr: string,
    expectingAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'MiningRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid recipient address').eq(expectingRecipientAddr);
        expect(event.args[2], 'invalid amount').eq(expectingAmount);
      },
      1
    );
  },

  emitBridgeOperatorRewardDistributedEvent: async function (
    tx: ContractTransaction,
    expectingCoinbaseAddr: string,
    expectingBridgeOperator: string,
    expectingRecipientAddr: string,
    expectingAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'BridgeOperatorRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid bridge operator').eq(expectingBridgeOperator);
        expect(event.args[2], 'invalid recipient address').eq(expectingRecipientAddr);
        expect(event.args[3], 'invalid amount').eq(expectingAmount);
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

  emitValidatorSetUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod: BigNumberish,
    expectingValidators: string[]
  ) {
    await expectEvent(
      contractInterface,
      'ValidatorSetUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid period').eq(expectingPeriod);
        expect(event.args[1], 'invalid validator set').eql(expectingValidators);
      },
      1
    );
  },

  emitBlockProducerSetUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod: BigNumberish,
    expectingBlockProducers: string[]
  ) {
    await expectEvent(
      contractInterface,
      'BlockProducerSetUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid period').eq(expectingPeriod);
        expect(event.args[1], 'invalid validator set').eql(expectingBlockProducers);
      },
      1
    );
  },
};
