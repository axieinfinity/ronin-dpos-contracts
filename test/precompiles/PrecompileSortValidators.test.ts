import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  PrecompileSortValidators,
  PrecompileSortValidators__factory,
  MockUsageSortValidators,
  MockUsageSortValidators__factory,
} from '../../src/types';
import { randomBigNumber } from '../../src/utils';
import { randomInt } from 'crypto';

let deployer: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let precompileSorting: PrecompileSortValidators;
let usageSorting: MockUsageSortValidators;

describe('[Precompile] Sorting validators test', () => {
  before(async () => {
    [deployer, ...validatorCandidates] = await ethers.getSigners();

    precompileSorting = await new PrecompileSortValidators__factory(deployer).deploy();
    usageSorting = await new MockUsageSortValidators__factory(deployer).deploy(precompileSorting.address);
  });

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageSorting.precompileSortValidatorAddress()).eq(precompileSorting.address);
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

    expect(sortedValidators).eql(expectingValidators);
  });

  it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
    await usageSorting.setPrecompileSortValidatorAddress(ethers.constants.AddressZero);
    await expect(usageSorting.callPrecompile([validatorCandidates[0].address], [1])).revertedWith(
      'UsageSortValidators: call to precompile fails'
    );
  });
});
