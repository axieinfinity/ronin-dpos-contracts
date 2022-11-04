import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPrecompile,
  MockPrecompile__factory,
  MockPrecompileUsageValidateDoubleSign,
  MockPrecompileUsageValidateDoubleSign__factory,
} from '../../src/types';
import { Network } from '../../src/utils';
import { BytesLike } from 'ethers';

let deployer: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let precompileValidating: MockPrecompile;
let usageValidating: MockPrecompileUsageValidateDoubleSign;

describe('[Precompile Integration] Validate double sign test', async () => {
  let onDevNet: boolean;

  before(async () => {
    [deployer, ...validatorCandidates] = await ethers.getSigners();

    if (network.name == Network.Devnet) {
      console.log('\x1b[35m ', `> Skipped deploying mock precompiled due to current network is "${Network.Devnet}".`);
      onDevNet = true;
    } else {
      console.log(
        '\x1b[35m ',
        `> Deployed mock precompiled due to current network is not "${Network.Devnet}". Current network: "${network.name}".`
      );

      precompileValidating = await new MockPrecompile__factory(deployer).deploy();
      usageValidating = await new MockPrecompileUsageValidateDoubleSign__factory(deployer).deploy(
        precompileValidating.address
      );
    }
  });

  describe('Config test', async () => {
    let header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
    let header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

    it('Should the usage contract correctly configs the precompile address', async () => {
      expect(await usageValidating.precompileValidateDoubleSignAddress()).eq(precompileValidating.address);
    });

    it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
      await usageValidating.setPrecompileValidateDoubleSignAddress(ethers.constants.AddressZero);
      await expect(usageValidating.callPrecompile(header1, header2)).revertedWith(
        'PrecompileUsageValidateDoubleSign: call to precompile fails'
      );
    });
  });

  describe('Functional test', function (this: Mocha.Suite) {
    const suite = this;

    before(async () => {
      if (!onDevNet) {
        console.log(
          '\x1b[35m   ',
          `> Skipped due to wrong network. Expected network: "${Network.Devnet}". Current network: "${network.name}".`
        );
        suite.ctx.skip();
      }
    });

    it('Should the validation failed when submitted block in 28,800 blocks behind of the current block height', async () => {
      let _header1: BytesLike = Buffer.from([]);
      let _header2: BytesLike = Buffer.from([]);

      await expect(usageValidating.callPrecompile(_header1, _header2)).revertedWith(
        'PrecompileUsageValidateDoubleSign: call to precompile fails'
      );
    });

    it('Should the validation failed when the parents of the two blocks mismatch', async () => {
      let _header1: BytesLike = Buffer.from([]);
      let _header2: BytesLike = Buffer.from([]);

      await expect(usageValidating.callPrecompile(_header1, _header2)).revertedWith(
        'PrecompileUsageValidateDoubleSign: call to precompile fails'
      );
    });

    it('Should the validation failed due to block producers of the two blocks mismatch', async () => {
      let _header1: BytesLike = Buffer.from([]);
      let _header2: BytesLike = Buffer.from([]);

      expect(await usageValidating.callPrecompile(_header1, _header2)).eq(true);
    });

    it('Should the validation success when the proof is valid', async () => {
      let _header1: BytesLike = Buffer.from([]);
      let _header2: BytesLike = Buffer.from([]);

      expect(await usageValidating.callPrecompile(_header1, _header2)).eq(true);
    });
  });
});
