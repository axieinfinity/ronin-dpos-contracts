import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { Staking__factory } from '../../../src/types';

const contractInterface = Staking__factory.createInterface();

export const expects = {
  emitPoolsUpdatedEvent: async function (
    tx: ContractTransaction,
    expectingPeriod?: BigNumberish,
    expectingPoolAddressList?: string[],
    expectingAccumulatedRpsList?: BigNumberish[]
  ) {
    await expectEvent(
      contractInterface,
      'PoolsUpdated',
      tx,
      (event) => {
        if (!!expectingPeriod) {
          expect(event.args[0], 'invalid period').deep.equal(expectingPeriod);
        }
        if (!!expectingPoolAddressList) {
          expect(event.args[1], 'invalid pool address list').deep.equal(expectingPoolAddressList);
        }
        if (!!expectingAccumulatedRpsList) {
          expect(event.args[2], 'invalid accumulated rps list').deep.equal(expectingAccumulatedRpsList);
        }
      },
      1
    );
  },
};
