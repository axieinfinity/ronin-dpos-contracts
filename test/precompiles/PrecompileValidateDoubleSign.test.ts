import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  PrecompileValidateDoubleSign,
  PrecompileValidateDoubleSign__factory,
  UsageValidateDoubleSign,
  UsageValidateDoubleSign__factory,
} from '../../src/types';

let deployer: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let precompileValidating: PrecompileValidateDoubleSign;
let usageValidating: UsageValidateDoubleSign;

describe('[Precompile] Validate double sign test', () => {
  before(async () => {
    [deployer, ...validatorCandidates] = await ethers.getSigners();

    precompileValidating = await new PrecompileValidateDoubleSign__factory(deployer).deploy();
    usageValidating = await new UsageValidateDoubleSign__factory(deployer).deploy(precompileValidating.address);
  });

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageValidating.precompileValidateDoubleSignAddress()).eq(precompileValidating.address);
  });

  it('Should the usage contract can call the precompile address', async () => {
    let header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
    let header2 = ethers.utils.toUtf8Bytes('sampleHeader2');
    let sortedValidators = await usageValidating.callPrecompile(header1, header2);
    expect(sortedValidators).eql(true);
  });
});
