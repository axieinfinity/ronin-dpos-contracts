import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPrecompile,
  MockPrecompile__factory,
  MockPrecompileUsageValidateDoubleSign,
  MockPrecompileUsageValidateDoubleSign__factory,
} from '../../src/types';

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let precompileValidating: MockPrecompile;
let usageValidating: MockPrecompileUsageValidateDoubleSign;

describe('[Precompile] Validate double sign test', () => {
  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();

    precompileValidating = await new MockPrecompile__factory(deployer).deploy();
    usageValidating = await new MockPrecompileUsageValidateDoubleSign__factory(deployer).deploy(
      precompileValidating.address
    );
  });

  let header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
  let header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageValidating.precompileValidateDoubleSignAddress()).eq(precompileValidating.address);
  });

  it('Should the usage contract can call the precompile address', async () => {
    let sortedValidators = await usageValidating.callPrecompile(header1, header2);
    expect(sortedValidators).eql(true);
  });

  it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
    await usageValidating.setPrecompileValidateDoubleSignAddress(ethers.constants.AddressZero);
    await expect(usageValidating.callPrecompile(header1, header2)).revertedWith(
      'PrecompileUsageValidateDoubleSign: call to precompile fails'
    );
  });
});
