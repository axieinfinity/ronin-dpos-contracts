import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { CandidateManager__factory } from '../../../src/types';

const contractInterface = CandidateManager__factory.createInterface();

export const expects = {
  emitCandidatesRevokedEvent: async function (tx: ContractTransaction, expectingRevokedCandidates: string[]) {
    await expectEvent(
      contractInterface,
      'CandidatesRevoked',
      tx,
      (event) => {
        expect(event.args[0], 'invalid revoked candidates').deep.equal(expectingRevokedCandidates);
      },
      1
    );
  },

  emitCandidateGrantedEvent: async function (
    tx: ContractTransaction,
    expectingConsensusAddr: string,
    expectingTreasuryAddr: string,
    expectingAdmin: string
  ) {
    await expectEvent(
      contractInterface,
      'CandidateGranted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid consensus address').deep.equal(expectingConsensusAddr);
        expect(event.args[1], 'invalid treasury address').deep.equal(expectingTreasuryAddr);
        expect(event.args[2], 'invalid admin address').deep.equal(expectingAdmin);
      },
      1
    );
  },
};
