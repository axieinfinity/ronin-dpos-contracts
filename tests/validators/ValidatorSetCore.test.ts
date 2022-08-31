import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { MockValidatorSetCore, MockValidatorSetCore__factory } from '../../src/types';
import { ValidatorCandidateStruct } from '../../src/types/ValidatorSetCoreMock';

let validatorsCore: MockValidatorSetCore;

let signers: SignerWithAddress[];
let candidates: ValidatorCandidateStruct[];
let admin: SignerWithAddress;
let stakingAddrs: SignerWithAddress[];
let consensusAddrs: SignerWithAddress[];
let treasuryAddrs: SignerWithAddress[];

const generateCandidate = (
  stakingAddr: string,
  consensusAddr: string,
  treasuryAddr: string
): ValidatorCandidateStruct => {
  return {
    stakingAddr: stakingAddr,
    consensusAddr: consensusAddr,
    treasuryAddr: treasuryAddr,
    commissionRate: 0,
    stakedAmount: 0,
    delegatedAmount: 0,
    governing: false,
    ____gap: Array.apply(null, Array(20)).map((_) => 0),
  };
};

describe('Validator set core tests', () => {
  describe('CRUD functions on validator set', async () => {
    describe('Simple CRUD', async () => {
      before(async () => {
        [admin, ...signers] = await ethers.getSigners();
        validatorsCore = await new MockValidatorSetCore__factory(admin).deploy();

        candidates = [];
        stakingAddrs = [];
        consensusAddrs = [];
        treasuryAddrs = [];

        for (let i = 0; i < 7; i++) {
          candidates.push(
            generateCandidate(signers[3 * i].address, signers[3 * i + 1].address, signers[3 * i + 2].address)
          );
          stakingAddrs.push(signers[3 * i]);
          consensusAddrs.push(signers[3 * i + 1]);
          treasuryAddrs.push(signers[3 * i + 2]);
        }
      });

      it('Should be able to set one validator (set unexisted validator)', async () => {
        await validatorsCore.setValidator(candidates[1], false);
        let validator = await validatorsCore.getValidator(consensusAddrs[1].address);
        expect(candidates[1].consensusAddr).eq(validator.consensusAddr);
        expect(candidates[1].treasuryAddr).eq(validator.treasuryAddr);
      });

      it('Should be able to set one validator (skip to set existed validator, not forced)', async () => {
        await validatorsCore.setValidator(candidates[1], false);
        let validator = await validatorsCore.getValidator(consensusAddrs[1].address);
        expect(candidates[1].consensusAddr).eq(validator.consensusAddr);
        expect(candidates[1].treasuryAddr).eq(validator.treasuryAddr);
      });

      it('Should be able to set one validator (set existed validator, forced, to update treasury address)', async () => {
        candidates[1].treasuryAddr = treasuryAddrs[5].address;
        await validatorsCore.setValidator(candidates[1], true);
        let validator = await validatorsCore.getValidator(consensusAddrs[1].address);
        expect(candidates[1].consensusAddr).eq(validator.consensusAddr);
        expect(treasuryAddrs[5].address).eq(validator.treasuryAddr);
      });

      it('Should fail to query in mining validator set', async () => {
        let miningValidator = validatorsCore.getValidatorAtMiningIndex(1);
        await expect(miningValidator).to.revertedWith('Validator: No validator exists at queried mining index');
      });

      it('Should be able set the added validator at 1-index slot (skipping add new validator on actual set)', async () => {
        await validatorsCore.setValidatorAtMiningIndex(1, candidates[1]);
        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(1);
        await expect(miningValidator.consensusAddr).eq(candidates[1].consensusAddr);
      });

      it('Should not be able to retrieve validator at 2-index slot while having 1 validator in the list', async () => {
        await expect(validatorsCore.getValidatorAtMiningIndex(2)).to.revertedWith(
          'Validator: No validator exists at queried mining index'
        );
      });

      it('Should be able to add a new validator at 2-index slot while having 1 validator in the list (set new on actual set)', async () => {
        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(1);
        await expect(miningValidator.consensusAddr).eq(candidates[1].consensusAddr);
        await validatorsCore.setValidatorAtMiningIndex(2, candidates[2]);
        miningValidator = await validatorsCore.getValidatorAtMiningIndex(2);
        await expect(miningValidator.consensusAddr).eq(candidates[2].consensusAddr);
      });

      it('Should not be able to add a new validator at 4-index slot while having 2 validator in the list', async () => {
        await expect(validatorsCore.setValidatorAtMiningIndex(4, candidates[3])).to.revertedWith(
          'Validator: Cannot set at out-of-bound mining set'
        );
      });

      it('Should be able to swap the validator', async () => {
        await validatorsCore.setValidator(candidates[6], true);
        await validatorsCore.setValidatorAtMiningIndex(2, candidates[6]);
        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(2);
        await expect(miningValidator.consensusAddr).eq(candidates[6].consensusAddr);
        await expect(validatorsCore.getValidatorAtMiningIndex(3)).to.revertedWith(
          'Validator: No validator exists at queried mining index'
        );
      });

      it('Should be able to remove the validator', async () => {
        expect(await validatorsCore.getCurrentValidatorSetSize()).to.eq(2);
        await validatorsCore.popValidatorFromMiningIndex();
        expect(await validatorsCore.getCurrentValidatorSetSize()).to.eq(1);
      });
    });

    describe('Stress test', async () => {
      before(async () => {
        [admin, ...signers] = await ethers.getSigners();
        candidates = [];
        validatorsCore = await new MockValidatorSetCore__factory(admin).deploy();

        for (let i = 0; i < 33; i++) {
          candidates.push(
            generateCandidate(signers[3 * i].address, signers[3 * i + 1].address, signers[3 * i + 2].address)
          );
        }
      });

      it('Should be able to add 10 validators', async () => {
        for (let i = 1; i <= 10; i++) {
          await validatorsCore.setValidator(candidates[i], false);
          let _validator = await validatorsCore.getValidator(candidates[i].consensusAddr);
          expect(_validator.consensusAddr).eq(candidates[i].consensusAddr);
        }
      });

      it('Should be able to set in the indexes 10 new validators', async () => {
        for (let i = 1; i <= 10; i++) {
          await validatorsCore.setValidatorAtMiningIndex(i, candidates[i]);
          let _validator = await validatorsCore.getValidatorAtMiningIndex(i);
          await expect(_validator.consensusAddr).eq(candidates[i].consensusAddr);
        }
      });

      it('Should be able to swap 10 existed validators', async () => {
        let swapTable = [...Array(10).keys()].map((x) => ++x).sort(() => 0.5 - Math.random());

        console.log(swapTable);

        for (let i = 1; i <= 10; i++) {
          console.log('>>> Swap index', i, 'to', swapTable[i - 1]);
          await validatorsCore.setValidatorAtMiningIndex(i, candidates[swapTable[i - 1]]);
          let _validator = await validatorsCore.getValidatorAtMiningIndex(i);
          expect(_validator.consensusAddr).eq(candidates[swapTable[i - 1]].consensusAddr);
        }
      });

      it('Should be able to add 20 validators more', async () => {
        for (let i = 11; i <= 30; i++) {
          await validatorsCore.setValidator(candidates[i], false);
          let _validator = await validatorsCore.getValidator(candidates[i].consensusAddr);
          expect(_validator.consensusAddr).eq(candidates[i].consensusAddr);
        }
      });

      it('Should be able to set in the indexes for 11 new validators', async () => {
        for (let i = 11; i <= 21; i++) {
          await validatorsCore.setValidatorAtMiningIndex(i, candidates[i]);
          let _validator = await validatorsCore.getValidatorAtMiningIndex(i);
          await expect(_validator.consensusAddr).eq(candidates[i].consensusAddr);
        }
      });

      it('Should be able to swap 21 existed validators', async () => {
        let swapTable = [...Array(21).keys()].map((x) => ++x).sort(() => 0.5 - Math.random());

        console.log(swapTable);

        for (let i = 1; i <= 21; i++) {
          console.log('>>> Swap index', i, 'to', swapTable[i - 1]);
          await validatorsCore.setValidatorAtMiningIndex(i, candidates[swapTable[i - 1]]);
          let _validator = await validatorsCore.getValidatorAtMiningIndex(i);
          expect(_validator.consensusAddr).eq(candidates[swapTable[i - 1]].consensusAddr);
        }
      });
    });
  });
});
