import { ethers, network } from 'hardhat';

import { expect } from 'chai';
import { ContractTransaction } from 'ethers';

import { expectEvent } from './utils';
import { CandidateManager__factory } from '../../src/types';

const contractInterface = CandidateManager__factory.createInterface();

export const expects = {
  emitCandidatesRevokedEvent: async function (tx: ContractTransaction, expectingRevokedCandidates: string[]) {
    await expectEvent(
      contractInterface,
      'CandidatesRevoked',
      tx,
      (event) => {
        expect(event.args[0], 'invalid revoked candidates').eql(expectingRevokedCandidates);
      },
      1
    );
  },

  emitCandidateGrantedEvent: async function (
    tx: ContractTransaction,
    expectingConsensusAddr: string,
    expectingTreasuryAddr: string,
    expectingAdmin: string,
    expectingBridgeOperatorAddr: string
  ) {
    await expectEvent(
      contractInterface,
      'CandidateGranted',
      tx,
      (event) => {
        expect(event.args[0], 'invalid consensus address').eql(expectingConsensusAddr);
        expect(event.args[1], 'invalid treasury address').eql(expectingTreasuryAddr);
        expect(event.args[2], 'invalid admin address').eql(expectingAdmin);
        expect(event.args[3], 'invalid bridge operator address').eql(expectingBridgeOperatorAddr);
      },
      1
    );
  },
};
