import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { RoninValidatorSet__factory } from '../../../src/types';
import { BlockRewardDeprecatedType } from '../../../src/script/ronin-validator-set';

const contractInterface = RoninValidatorSet__factory.createInterface();

export class EpochController {
  readonly minOffsetToStartSchedule: number;
  readonly numberOfBlocksInEpoch: number;

  constructor(minOffsetToStartSchedule: number, numberOfBlocksInEpoch: number) {
    this.minOffsetToStartSchedule = minOffsetToStartSchedule;
    this.numberOfBlocksInEpoch = numberOfBlocksInEpoch;
  }

  calculateStartOfEpoch(block: number): BigNumber {
    return BigNumber.from(
      Math.floor((block + this.minOffsetToStartSchedule) / this.numberOfBlocksInEpoch + 1) * this.numberOfBlocksInEpoch
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

    if (includingEpochsNum! && BigNumber.from(includingEpochsNum!).gt(1)) {
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
    expectingBlockProducerBonus: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'BlockRewardSubmitted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid coinbase address').eq(expectingCoinbaseAddr);
        expect(event.args[1], 'invalid submitted reward').eq(expectingSubmittedReward);
        expect(event.args[2], 'invalid staking vesting').eq(expectingBlockProducerBonus);
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

  emitStakingRewardDistributedEvent: async function (
    tx: ContractTransaction,
    expectingTotalAmount: BigNumberish,
    expectingValidators: string[] | undefined,
    expectingAmounts: BigNumberish[] | undefined
  ) {
    await expectEvent(
      contractInterface,
      'StakingRewardDistributed',
      tx,
      (event) => {
        expect(event.args[0], 'invalid total distributing reward').eq(expectingTotalAmount);
        if (expectingValidators) {
          expect(event.args[1], 'invalid validator list').deep.equal(expectingValidators);
        }
        if (expectingAmounts) {
          expect(event.args[2], 'invalid amount list').deep.equal(expectingAmounts);
        }
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
        expect(event.args[1], 'invalid validator set').deep.equal(expectingValidators);
      },
      1
    );
  },

  emitBlockProducerSetUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod?: BigNumberish,
    expectingEpoch?: BigNumberish,
    expectingBlockProducers?: string[]
  ) {
    await expectEvent(
      contractInterface,
      'BlockProducerSetUpdated',
      tx,
      (event) => {
        !!expectingPeriod && expect(event.args[0], 'invalid period').eq(expectingPeriod);
        !!expectingEpoch && expect(event.args[1], 'invalid epoch').eq(expectingEpoch);
        !!expectingBlockProducers &&
          expect(event.args[2], 'invalid block producers').deep.equal(expectingBlockProducers);
      },
      1
    );
  },

  emitBridgeOperatorSetUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod?: BigNumberish,
    expectingEpoch?: BigNumberish,
    expectingBridgeOperators?: string[]
  ) {
    await expectEvent(
      contractInterface,
      'BridgeOperatorSetUpdated',
      tx,
      (event) => {
        !!expectingPeriod && expect(event.args[0], 'invalid period').eq(expectingPeriod);
        !!expectingEpoch && expect(event.args[1], 'invalid epoch').eq(expectingEpoch);
        !!expectingBridgeOperators &&
          expect(event.args[2], 'invalid bridge operators').deep.equal(expectingBridgeOperators);
      },
      1
    );
  },

  emitBlockRewardDeprecatedEvent: async function (
    tx: ContractTransaction,
    expectingValidator: string,
    expectingRemovedReward: BigNumberish,
    expectingDeprecatedType: BlockRewardDeprecatedType
  ) {
    await expectEvent(
      contractInterface,
      'BlockRewardDeprecated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid validator').eq(expectingValidator);
        expect(event.args[1], 'invalid removed reward').deep.equal(expectingRemovedReward);
        expect(event.args[2], 'invalid deprecated type').deep.equal(expectingDeprecatedType);
      },
      1
    );
  },

  emitDeprecatedRewardRecycledEvent: async function (
    tx: ContractTransaction,
    expectingWithdrawnTarget: string,
    expectingWithdrawnAmount: BigNumberish
  ) {
    await expectEvent(
      contractInterface,
      'DeprecatedRewardRecycled',
      tx,
      (event) => {
        expect(event.args[0], 'invalid withdraw target').eq(expectingWithdrawnTarget);
        expect(event.args[1], 'invalid withdraw amount').deep.equal(expectingWithdrawnAmount);
      },
      1
    );
  },
};
