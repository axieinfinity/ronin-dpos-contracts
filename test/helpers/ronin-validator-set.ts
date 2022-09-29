import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { RoninValidatorSet__factory } from '../../src/types';

const contractInterface = RoninValidatorSet__factory.createInterface();

export class EpochController {
  readonly minOffset: number;
  readonly numberOfBlocksInEpoch: number;
  readonly numberOfEpochsInPeriod: number;
  readonly numberOfBlocksInPeriod: number;

  constructor(minOffset: number, numberOfBlocksInEpoch: number, numberOfEpochsInPeriod: number) {
    this.minOffset = minOffset;
    this.numberOfBlocksInEpoch = numberOfBlocksInEpoch;
    this.numberOfEpochsInPeriod = numberOfEpochsInPeriod;
    this.numberOfBlocksInPeriod = numberOfBlocksInEpoch * numberOfEpochsInPeriod;
  }

  calculateStartOfEpoch(block: number): BigNumber {
    return BigNumber.from(
      Math.floor((block + this.minOffset) / this.numberOfBlocksInEpoch + 1) * this.numberOfBlocksInEpoch
    );
  }

  diffToEndEpoch(block: BigNumberish): BigNumber {
    return BigNumber.from(this.numberOfBlocksInEpoch).sub(BigNumber.from(block).mod(this.numberOfBlocksInEpoch)).sub(1);
  }

  diffToEndPeriod(block: BigNumberish): BigNumber {
    return BigNumber.from(this.numberOfBlocksInPeriod)
      .sub(BigNumber.from(block).mod(this.numberOfBlocksInPeriod))
      .sub(1);
  }

  calculateEndOfEpoch(block: BigNumberish): BigNumber {
    return BigNumber.from(block).add(this.diffToEndEpoch(block));
  }

  calculateEndOfPeriod(block: BigNumberish): BigNumber {
    return BigNumber.from(block).add(this.diffToEndPeriod(block));
  }

  calculatePeriodOf(block: BigNumberish): BigNumber {
    if (block == 0) {
      return BigNumber.from(0);
    }
    return BigNumber.from(block).div(BigNumber.from(this.numberOfBlocksInPeriod)).add(1);
  }

  async currentPeriod(): Promise<BigNumber> {
    return this.calculatePeriodOf(await ethers.provider.getBlockNumber());
  }

  async mineToBeforeEndOfEpoch() {
    let number = this.diffToEndEpoch(await ethers.provider.getBlockNumber()).sub(1);
    if (number.lt(0)) {
      number = number.add(this.numberOfBlocksInEpoch);
    }
    return network.provider.send('hardhat_mine', [ethers.utils.hexStripZeros(number.toHexString())]);
  }

  async mineToBeforeEndOfPeriod() {
    let number = this.diffToEndPeriod(await ethers.provider.getBlockNumber()).sub(1);
    if (number.lt(0)) {
      number = number.add(this.numberOfBlocksInPeriod);
    }
    return network.provider.send('hardhat_mine', [ethers.utils.hexStripZeros(number.toHexString())]);
  }

  async mineToBeginOfNewEpoch() {
    await this.mineToBeforeEndOfEpoch();
    return network.provider.send('hardhat_mine', ['0x2']);
  }

  async mineToBeginOfNewPeriod() {
    await this.mineToBeforeEndOfPeriod();
    return network.provider.send('hardhat_mine', ['0x2']);
  }
}

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
