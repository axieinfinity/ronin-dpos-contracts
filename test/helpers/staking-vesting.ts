import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { StakingVesting__factory } from '../../src/types';
import { Address } from 'hardhat-deploy/dist/types';

const contractInterface = StakingVesting__factory.createInterface();

export const expects = {
  emitBonusTransferredEvent: async function (
    tx: ContractTransaction,
    blockNumber?: BigNumberish,
    recipient?: Address,
    blockProducerBonus?: BigNumberish,
    bridgeOperatorBonus?: BigNumberish
  ) {
    const eventName = 'BonusTransferred';
    await expectEvent(
      contractInterface,
      eventName,
      tx,
      (event) => {
        if (blockNumber) {
          expect(event.args[0], eventName + ': invalid block number').eql(blockNumber);
        }
        if (recipient) {
          expect(event.args[1], eventName + ': invalid recipient').eql(recipient);
        }
        if (blockProducerBonus) {
          expect(event.args[2], eventName + ': invalid block producer bonus').eql(blockProducerBonus);
        }
        if (bridgeOperatorBonus) {
          expect(event.args[3], eventName + ': invalid bridge operator bonus').eql(bridgeOperatorBonus);
        }
      },
      1
    );
  },

  emitBonusTransferFailedEvent: async function (
    tx: ContractTransaction,
    blockNumber?: BigNumberish,
    recipient?: Address,
    blockProducerBonus?: BigNumberish,
    bridgeOperatorBonus?: BigNumberish
  ) {
    const eventName = 'BonusTransferFailed';
    await expectEvent(
      contractInterface,
      eventName,
      tx,
      (event) => {
        if (blockNumber) {
          expect(event.args[0], eventName + ': invalid block number').eql(blockNumber);
        }
        if (recipient) {
          expect(event.args[1], eventName + ': invalid recipient').eql(recipient);
        }
        if (blockProducerBonus) {
          expect(event.args[2], eventName + ': invalid block producer bonus').eql(blockProducerBonus);
        }
        if (bridgeOperatorBonus) {
          expect(event.args[3], eventName + ': invalid bridge operator bonus').eql(bridgeOperatorBonus);
        }
      },
      1
    );
  },
};
