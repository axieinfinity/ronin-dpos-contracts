import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { RewardCalculation__factory } from '../../src/types';

const contractInterface = RewardCalculation__factory.createInterface();

export const expects = {
  emitSettledPoolsUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPoolList?: string[],
    expectingAccumulatedRpsList?: BigNumberish[]
  ) {
    await expectEvent(
      contractInterface,
      'SettledPoolsUpdated',
      tx,
      (event) => {
        if (expectingPoolList) {
          expect(event.args[0], 'invalid pool list').eql(expectingPoolList);
        }
        if (expectingAccumulatedRpsList) {
          expect(event.args[1], 'invalid accumulated rps list').eql(expectingAccumulatedRpsList);
        }
      },
      1
    );
  },
};
