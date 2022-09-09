import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { MockSwapStorage, MockSwapStorage__factory } from '../../src/types';
import { ValidatorCandidateStruct } from '../../src/types/IStaking';

let swapping: MockSwapStorage;

let signers: SignerWithAddress[];
let candidates: ValidatorCandidateStruct[];
let admin: SignerWithAddress;

const generateCandidate = (
  candidateAdmin: string,
  consensusAddr: string,
  treasuryAddr: string
): ValidatorCandidateStruct => {
  return {
    candidateAdmin: candidateAdmin,
    consensusAddr: consensusAddr,
    treasuryAddr: treasuryAddr,
    commissionRate: 0,
    stakedAmount: 0,
    delegatedAmount: 0,
    governing: false,
    state: 0,
    ____gap: Array.apply(null, Array(20)).map((_) => 0),
  };
};

describe.skip('Mock swap struct on storage tests', () => {
  describe('Stress test', async () => {
    before(async () => {
      [admin, ...signers] = await ethers.getSigners();
      candidates = [];
      swapping = await new MockSwapStorage__factory(admin).deploy();

      for (let i = 0; i < 33; i++) {
        candidates.push(
          generateCandidate(signers[3 * i].address, signers[3 * i + 1].address, signers[3 * i + 2].address)
        );
      }
    });

    it('Should be able to add 2 validators', async () => {
      for (let i = 0; i < 2; i++) {
        await swapping.pushValidator(candidates[i]);
      }
    });

    it('Should be able to swap 2 existed validators', async () => {
      let swapTable = [1, 0];
      console.log(swapTable);
      for (let i = 0; i < 2; i++) {
        console.log('>>> Swap index', i, 'to', swapTable[i]);
        await swapping.swapValidators(i, swapTable[i]);
      }
    });

    it('Should be able to add 9 more validators', async () => {
      for (let i = 2; i <= 10; i++) {
        await swapping.pushValidator(candidates[i]);
      }
    });

    it('Should be able to swap 11 existed validators', async () => {
      let swapTable = [...Array(11).keys()].map((x) => x).sort(() => 0.5 - Math.random());
      console.log(swapTable);
      for (let i = 0; i <= 10; i++) {
        console.log('>>> Swap index', i, 'to', swapTable[i]);
        await swapping.swapValidators(i, swapTable[i]);
      }
    });

    it('Should be able to add 20 validators more', async () => {
      for (let i = 11; i <= 30; i++) {
        await swapping.pushValidator(candidates[i]);
      }
    });

    it('Should be able to swap 31 existed validators', async () => {
      let swapTable = [...Array(31).keys()].map((x) => x).sort(() => 0.5 - Math.random());
      console.log(swapTable);
      for (let i = 0; i <= 30; i++) {
        console.log('>>> Swap index', i, 'to', swapTable[i]);
        await swapping.swapValidators(i, swapTable[i]);
      }
    });
  });
});
