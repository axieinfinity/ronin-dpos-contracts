import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPrecompile,
  MockPrecompile__factory,
  MockPCUSortValidators,
  MockPCUSortValidators__factory,
} from '../../../src/types';
import { randomInt } from 'crypto';

let deployer: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let precompileSorting: MockPrecompile;
let usageSorting: MockPCUSortValidators;

describe('[Precompile] Sorting validators test', () => {
  before(async () => {
    [deployer, ...validatorCandidates] = await ethers.getSigners();

    precompileSorting = await new MockPrecompile__factory(deployer).deploy();
    usageSorting = await new MockPCUSortValidators__factory(deployer).deploy(precompileSorting.address);
  });

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageSorting.precompileSortValidatorsAddress()).eq(precompileSorting.address);
  });

  it('Should the usage contract can call the precompile address', async () => {
    let numOfValidator = 21;
    let validatorsAndWeights = Array.from({ length: numOfValidator }, (_, i) => {
      return {
        address: validatorCandidates[i].address,
        balance: randomInt(numOfValidator * 10000),
      };
    });

    let sortedValidators = await usageSorting.callPrecompile(
      validatorsAndWeights.map((_) => _.address),
      validatorsAndWeights.map((_) => _.balance)
    );

    let expectingValidators = validatorsAndWeights
      .sort((a, b) => (a.balance > b.balance ? -1 : 1))
      .map((_) => _.address);

    expect(sortedValidators).deep.equal(expectingValidators);
  });

  it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
    await usageSorting.setPrecompileSortValidatorAddress(ethers.constants.AddressZero);
    await expect(usageSorting.callPrecompile([validatorCandidates[0].address], [1])).revertedWithCustomError(
      usageSorting,
      'ErrCallPrecompiled'
    );
  });
});
