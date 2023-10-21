import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPrecompile,
  MockPrecompile__factory,
  MockPCUValidateFastFinality__factory,
  MockPCUValidateFastFinality,
} from '../../../src/types';
import { Address } from 'hardhat-deploy/dist/types';
import { MINTER_ROLE, SENTRY_ROLE } from '../../../src/utils';
import { BytesLike } from 'ethers';

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let precompileValidating: MockPrecompile;
let usageValidating: MockPCUValidateFastFinality;

describe('[Precompile] Validate fast finality', () => {
  let slasheeAddr: Address;

  let voterPublicKey = ethers.utils.toUtf8Bytes('samplePubKey');
  let targetBlockNumber = 1337;
  let targetBlockHash: [BytesLike, BytesLike] = [MINTER_ROLE, SENTRY_ROLE];
  let listOfPublicKey: [BytesLike[], BytesLike[]] = [
    [ethers.utils.toUtf8Bytes('pub1partA'), ethers.utils.toUtf8Bytes('pub1partB')],
    [ethers.utils.toUtf8Bytes('pub2partA'), ethers.utils.toUtf8Bytes('pub2partB')],
  ];
  let aggregatedSignature: [BytesLike, BytesLike] = [
    ethers.utils.toUtf8Bytes('signature1'),
    ethers.utils.toUtf8Bytes('signature2'),
  ];

  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();

    precompileValidating = await new MockPrecompile__factory(deployer).deploy();
    usageValidating = await new MockPCUValidateFastFinality__factory(deployer).deploy(precompileValidating.address);

    slasheeAddr = signers[0].address;
  });

  it('Should the usage contract correctly configs the precompile address', async () => {
    expect(await usageValidating.precompileValidateFastFinalityAddress()).eq(precompileValidating.address);
  });

  it('Should the usage contract can call the precompile address', async () => {
    let sortedValidators = await usageValidating.callPrecompile(
      voterPublicKey,
      targetBlockNumber,
      targetBlockHash,
      listOfPublicKey,
      aggregatedSignature
    );
    expect(sortedValidators).deep.equal(true);
  });

  it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
    await usageValidating.setPrecompileValidateFastFinalityAddress(ethers.constants.AddressZero);
    await expect(
      usageValidating.callPrecompile(
        voterPublicKey,
        targetBlockNumber,
        targetBlockHash,
        listOfPublicKey,
        aggregatedSignature
      )
    ).revertedWithCustomError(usageValidating, 'ErrCallPrecompiled');
  });
});
