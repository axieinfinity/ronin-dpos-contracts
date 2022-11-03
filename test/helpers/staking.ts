import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { Staking__factory } from '../../src/types';

const contractInterface = Staking__factory.createInterface();

export const expects = {
  emitPoolsUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod: BigNumberish,
    expectingPoolAddressList: string[],
    expectingAccumulatedRpsList: BigNumberish[]
  ) {
    await expectEvent(
      contractInterface,
      'PoolsUpdated',
      tx,
      (event) => {
        expect(event.args[0], 'invalid period').eql(expectingPeriod);
        expect(event.args[1], 'invalid pool address list').eql(expectingPoolAddressList);
        expect(event.args[2], 'invalid accumulated rps list').eql(expectingAccumulatedRpsList);
      },
      1
    );
  },
};
