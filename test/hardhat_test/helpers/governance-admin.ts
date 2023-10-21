import { expect } from 'chai';

import { expectEvent } from './utils';
import { GovernanceAdmin__factory, RoninValidatorSet__factory } from '../../../src/types';
import { ContractTransaction } from 'ethers';

const contractInterface = GovernanceAdmin__factory.createInterface();

export const expects = {
  emitProposalExecutedEvent: async function (
    tx: ContractTransaction,
    expectingProposalHash: string,
    expectingSuccessCalls: boolean[],
    expectingReturnedDatas: string[]
  ) {
    await expectEvent(
      contractInterface,
      'ProposalExecuted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid proposal hash').eq(expectingProposalHash);
        expect(event.args[1], 'invalid success calls').deep.equal(expectingSuccessCalls);
        expect(event.args[2], 'invalid returned datas').deep.equal(expectingReturnedDatas);
      },
      1
    );
  },
};
