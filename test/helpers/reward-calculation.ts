import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from '../utils';
import { RewardCalculation__factory } from '../types';

const contractInterface = RewardCalculation__factory.createInterface();

export const expects = {
  emitSettledPoolsUpdatedEvent: async function (
    tx: ContractTransaction,
    expectedPoolList?: string[],
    expectedAccumulatedRpsList?: BigNumberish[]
  ) {
    await expectEvent(
      contractInterface,
      'SettledPoolsUpdated',
      tx,
      (event) => {
        if (expectedPoolList) {
          expect(event.args[0], 'invalid pool list').eql(expectedPoolList);
        }
        if (expectedAccumulatedRpsList) {
          expect(event.args[1], 'invalid accumulated rps list').eql(expectedAccumulatedRpsList);
        }
      },
      1
    );
  },
};
