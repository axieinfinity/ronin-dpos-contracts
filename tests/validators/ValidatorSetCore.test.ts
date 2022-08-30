import { expect } from 'chai';
import { deployments, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  ValidatorSetCore,
  ValidatorSetCore__factory,
  MockValidatorSetCore,
  MockValidatorSetCore__factory,
} from '../../src/types';
import { ValidatorStruct, ValidatorCandidateStruct } from '../../src/types/ValidatorSetCoreMock';
import { BigNumber } from 'ethers/lib/ethers';
import { DEFAULT_ADDRESS } from '../../src/utils';

let validatorsCore: MockValidatorSetCore;

let admin: SignerWithAddress;
let s1: SignerWithAddress;
let s2: SignerWithAddress;
let s3: SignerWithAddress;
let s4: SignerWithAddress;
let s5: SignerWithAddress;
let s6: SignerWithAddress;
let v1: SignerWithAddress;
let v2: SignerWithAddress;
let v3: SignerWithAddress;
let v4: SignerWithAddress;
let v5: SignerWithAddress;
let v6: SignerWithAddress;
let candidate1: ValidatorCandidateStruct;
let candidate2: ValidatorCandidateStruct;
let candidate3: ValidatorCandidateStruct;
let candidate4: ValidatorCandidateStruct;
let candidate5: ValidatorCandidateStruct;
let candidate6: ValidatorCandidateStruct;

const generateCandidate = (stakingAddr: string, consensusAddr: string): ValidatorCandidateStruct => {
  return {
    stakingAddr: stakingAddr,
    consensusAddr: consensusAddr,
    treasuryAddr: DEFAULT_ADDRESS,
    commissionRate: 0,
    stakedAmount: 0,
    delegatedAmount: 0,
    governing: false,
    ____gap: Array.apply(null, Array(20)).map((_) => 0),
  };
};

describe('Validator set core tests', () => {
  describe('CRUD functions on validator set', async () => {
    before(async () => {
      [admin, s1, s2, s3, s4, s5, s6, v1, v2, v3, v4, v5, v6] = await ethers.getSigners();
      validatorsCore = await new MockValidatorSetCore__factory(admin).deploy();

      candidate1 = generateCandidate(s1.address, v1.address);
      candidate2 = generateCandidate(s2.address, v2.address);
      candidate3 = generateCandidate(s3.address, v3.address);
      candidate4 = generateCandidate(s4.address, v4.address);
      candidate5 = generateCandidate(s5.address, v5.address);
      candidate6 = generateCandidate(s6.address, v6.address);
    });

    describe('Simple CRUD', async () => {
      it('Should be able to set one validator (set unexisted validator)', async () => {
        await validatorsCore.setValidator(candidate1, false);

        let validator = await validatorsCore.getValidator(v1.address);
        expect(candidate1.consensusAddr).eq(validator.consensusAddr);
      });

      it('Should added validator not be in the current mining index', async () => {
        let miningValidator = validatorsCore.getValidatorAtMiningIndex(0);
        await expect(miningValidator).to.revertedWith('No validator exists at queried mining index');
      });

      it('Should be able set the added validator at 0 mining slot (skipping add new validator on actual set)', async () => {
        await validatorsCore.setValidatorAtMiningIndex(0, candidate1);

        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(0);
        await expect(miningValidator.consensusAddr).eq(candidate1.consensusAddr);
      });

      it('Should not be able to retrieve validator at 1-index while having 1 validator in the list', async () => {
        await expect(validatorsCore.getValidatorAtMiningIndex(1)).to.revertedWith(
          'No validator exists at queried mining index'
        );
      });

      it('Should be able to add a new validator at 1-slot while having 1 validator in the list', async () => {
        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(0);
        await expect(miningValidator.consensusAddr).eq(candidate1.consensusAddr);

        await validatorsCore.setValidatorAtMiningIndex(1, candidate2);

        miningValidator = await validatorsCore.getValidatorAtMiningIndex(1);
        await expect(miningValidator.consensusAddr).eq(candidate2.consensusAddr);
      });

      it('Should not be able to add a new validator at 3-slot while having 2 validator in the list', async () => {
        await expect(validatorsCore.setValidatorAtMiningIndex(3, candidate3)).to.revertedWith(
          'Cannot set mining index greater than current indexes array length'
        );
      });

      it('Should be able to swap the validator', async () => {
        await validatorsCore.setValidator(candidate6, true);
        await validatorsCore.setValidatorAtMiningIndex(1, candidate6);

        let miningValidator = await validatorsCore.getValidatorAtMiningIndex(1);
        await expect(miningValidator.consensusAddr).eq(candidate6.consensusAddr);

        await expect(validatorsCore.getValidatorAtMiningIndex(2)).to.revertedWith(
          'No validator exists at queried mining index'
        );
      });

      it('Should be able to remove the validator', async () => {
        await validatorsCore.removeValidatorAtMiningIndex(1);
        
        await expect(validatorsCore.getValidatorAtMiningIndex(1)).to.revertedWith(
          'No validator exists at queried mining index'
        );
      });
    });
  });
});
