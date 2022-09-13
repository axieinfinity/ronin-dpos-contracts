import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { Staking__factory } from '../../src/types';

const contractInterface = Staking__factory.createInterface();

export const expects = {
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
};
