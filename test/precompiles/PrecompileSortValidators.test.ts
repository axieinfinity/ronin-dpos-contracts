import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  PrecompileSortValidators,
  PrecompileSortValidators__factory,
  UsageSortValidators,
  UsageSortValidators__factory,
} from '../../src/types';

let deployer: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let precompileSorting: PrecompileSortValidators;
let usageSorting: UsageSortValidators;

describe('Precompile sorting validators test', () => {
  before(async () => {
    [deployer, ...validatorCandidates] = await ethers.getSigners();

    precompileSorting = await new PrecompileSortValidators__factory(deployer).deploy();
    usageSorting = await new UsageSortValidators__factory(deployer).deploy(precompileSorting.address);
  });

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageSorting.precompileSortValidatorAddress()).eq(precompileSorting.address);
  });

  it('Should the usage contract can call the precompile address', async () => {
    let inputValidators = await usageSorting.getValidators();
    let expectingValidators = [...inputValidators].reverse();
    let sortedValidators = await usageSorting.callPrecompile();

    expect(sortedValidators).eql(expectingValidators);
  });
});
