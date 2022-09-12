import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from '../utils';
import { ISlashIndicator__factory } from '../types';

const contractInterface = ISlashIndicator__factory.createInterface();

export const expects = {
  emitUnavailabilityIndicatorsResetEvent: async function (tx: ContractTransaction, expectedValidatorList?: string[]) {
    await expectEvent(
      contractInterface,
      'UnavailabilityIndicatorsReset',
      tx,
      (event) => {
        if (expectedValidatorList) {
          expect(event.args[0], 'invalid reset validator list').eql(expectedValidatorList);
        }
      },
      1
    );
  },
};
