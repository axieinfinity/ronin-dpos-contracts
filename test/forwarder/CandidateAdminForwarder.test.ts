import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';

import {
  CandidateAdminForwarder,
  CandidateAdminForwarder__factory,
  MockForwarderTarget,
  MockForwarderTarget__factory,
} from '../../src/types';
import { ADMIN_SLOT, TARGET_SLOT } from '../../src/utils';

let deployer: SignerWithAddress;
let admin: SignerWithAddress;
let user: SignerWithAddress;
let forwarder: CandidateAdminForwarder;
let target: MockForwarderTarget;
let localData: BigNumber;

describe('Candidate admin forwarder', () => {
  before(async () => {
    [deployer, admin, user] = await ethers.getSigners();

    localData = BigNumber.from(0);
    target = await new MockForwarderTarget__factory(deployer).deploy(localData);
    forwarder = await new CandidateAdminForwarder__factory(deployer).deploy(target.address, admin.address);
  });

  describe('Configuration test', async () => {
    before(async () => {
      forwarder = CandidateAdminForwarder__factory.connect(forwarder.address, admin);
    });

    it('Should the forward config the target correctly', async () => {
      expect(await network.provider.send('eth_getStorageAt', [forwarder.address, TARGET_SLOT])).eq(
        ['0x', '0'.repeat(24), target.address.toLocaleLowerCase().slice(2)].join('')
      );
    });
    it('Should the forward config the admin correctly', async () => {
      expect(await network.provider.send('eth_getStorageAt', [forwarder.address, ADMIN_SLOT])).eq(
        ['0x', '0'.repeat(24), admin.address.toLocaleLowerCase().slice(2)].join('')
      );
    });
  });

  describe('Calls from normal user', async () => {
    it('Should be able to call foo function ', async () => {});
    it('Should be able to call payable foo function ', async () => {});
    it("Should be able to call function of target, that has the same name with admin's", async () => {});
    it('Should be able to call fallback', async () => {});
    it('Should be able to call receive', async () => {});
    it('Should not be able to call the function of admin', async () => {});
  });

  describe('Calls from admin user', async () => {
    it('Should be able to call foo function ', async () => {});
    it('Should be able to call payable foo function ', async () => {});
    it("Should be able to call function of target, that has the same name with admin's", async () => {});
    it('Should be able to call fallback', async () => {});
    it('Should be able to call receive', async () => {});
    it('Should be able to call the function of admin', async () => {});
  });
});
