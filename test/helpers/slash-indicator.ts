import { expect } from 'chai';
import { BigNumberish, ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { ISlashIndicator__factory } from '../../src/types';

const contractInterface = ISlashIndicator__factory.createInterface();

export const expects = {
  emitUnavailabilityIndicatorsResetEvent: async function (tx: ContractTransaction, expectingValidatorList?: string[]) {
    await expectEvent(
      contractInterface,
      'UnavailabilityIndicatorsReset',
      tx,
      (event) => {
        if (expectingValidatorList) {
          expect(event.args[0], 'invalid reset validator list').eql(expectingValidatorList);
        }
      },
      1
    );
  },
};
