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
import { ADMIN_SLOT, DEFAULT_ADDRESS, TARGET_SLOT, ZERO_BYTES32 } from '../../src/utils';
import { calculateAddress } from '../helpers/utils';
import { parseEther } from 'ethers/lib/utils';

let deployer: SignerWithAddress;
let admin: SignerWithAddress;
let moderator: SignerWithAddress;
let unauthorized: SignerWithAddress;
let forwarder: CandidateAdminForwarder;
let targetBehindForwarder: MockForwarderTarget;
let target: MockForwarderTarget;
let localData: BigNumber;

describe('Candidate admin forwarder', () => {
  before(async () => {
    [deployer, admin, moderator, unauthorized] = await ethers.getSigners();

    let nonce = await ethers.provider.getTransactionCount(deployer.address);
    let forwarderAddress = calculateAddress(deployer.address, nonce + 2).address;

    await deployer.sendTransaction({
      to: forwarderAddress,
      value: parseEther('1.0'),
    });

    localData = BigNumber.from(0);
    target = await new MockForwarderTarget__factory(deployer).deploy(forwarderAddress, localData);
    forwarder = await new CandidateAdminForwarder__factory(deployer).deploy(target.address, admin.address);
  });

  describe('Configuration test', async () => {
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

  describe('Access grant', async () => {
    before(async () => {
      forwarder = CandidateAdminForwarder__factory.connect(forwarder.address, admin);
    });
    it('Should the admin be able to grant moderator role', async () => {
      const MODERATOR_ROLE = await forwarder.MODERATOR_ROLE();
      await forwarder.grantRole(MODERATOR_ROLE, moderator.address);
      expect(await forwarder.hasRole(MODERATOR_ROLE, moderator.address)).eq(true);
    });
  });

  describe('Calls from normal user', async () => {
    before(async () => {
      forwarder = CandidateAdminForwarder__factory.connect(forwarder.address, moderator);
      target = MockForwarderTarget__factory.connect(target.address, moderator);
      targetBehindForwarder = MockForwarderTarget__factory.connect(forwarder.address, moderator);
    });

    it('Should be able to call non-payable foo function', async () => {
      await targetBehindForwarder.foo(2);
      expect(await target.data()).eq(2);
    });

    it('Should be able to call payable foo function, with fund from caller account', async () => {
      expect(await targetBehindForwarder.fooPayable(3, { value: 100 })).changeEtherBalances(
        [moderator.address, target.address],
        [-100, 100]
      );
      expect(await target.data()).eq(3);
      expect(await target.getBalance()).eq(100);
    });

    it('Should be able to call payable foo function, with fund from forwarder account', async () => {
      expect(
        await forwarder.functionCall(target.interface.encodeFunctionData('fooPayable', [4]), 200)
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [0, -200, 200]);
      expect(await target.data()).eq(4);
      expect(await target.getBalance()).eq(300);
    });

    it("Should be able to call function of target, that has the same name with admin's function", async () => {
      await expect(targetBehindForwarder.withdrawAll()).changeEtherBalances(
        [forwarder.address, target.address],
        [300, -300]
      );
    });

    it('Should be able to invoke fallback of target through forwarder', async () => {
      await expect(
        moderator.sendTransaction({
          data: '0xdeadbeef',
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).revertedWith('MockForwardTarget: hello from fallback');
    });

    it('Should not be able to invoke receive of target through forwarder', async () => {
      await expect(
        moderator.sendTransaction({
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should not be able to call the function of admin: invokes target method', async () => {
      // overloaded method in target is invoked here
      let tx;
      await expect(async () => (tx = forwarder.withdrawAll())).changeEtherBalances(
        [moderator.address, forwarder.address, target.address],
        [0, 0, 0]
      );

      expect(tx).emit(target, 'TargetWithdrawn').withArgs(moderator.address, forwarder.address, forwarder.address);
      expect(tx).not.emit(forwarder, 'ForwarderWithdrawn');
    });
  });

  describe('Calls from admin user', async () => {
    before(async () => {
      forwarder = CandidateAdminForwarder__factory.connect(forwarder.address, admin);
      target = MockForwarderTarget__factory.connect(target.address, admin);
      targetBehindForwarder = MockForwarderTarget__factory.connect(forwarder.address, admin);
    });

    it('Should not be able to call non-payable foo function', async () => {
      await targetBehindForwarder.foo(2);
      expect(await target.data()).not.eq(2);
    });

    it('Should be able to call non-payable foo function by force `functionCall`', async () => {
      expect(await forwarder.functionCall(target.interface.encodeFunctionData('foo', [12]), 0)).changeEtherBalances(
        [admin.address, forwarder.address, target.address],
        [0, 0, 0]
      );
      expect(await target.data()).eq(12);
    });

    it('Should be able to call payable foo function, with fund from forwarder account', async () => {
      expect(
        await forwarder.functionCall(target.interface.encodeFunctionData('fooPayable', [13]), 300)
      ).changeEtherBalances([admin.address, forwarder.address, target.address], [-300, 0, 300]);
    });

    it('Should not be able to invoke fallback of target through forwarder: invokes forwarder', async () => {
      let tx;
      await expect(
        async () =>
          (tx = admin.sendTransaction({
            data: '0xdeadbeef',
            to: targetBehindForwarder.address,
            value: 200,
          }))
      ).changeEtherBalances([admin.address, forwarder.address, target.address], [-200, 200, 0]);

      expect(tx).not.revertedWith('MockForwardTarget: hello from fallback');
    });

    it('Should not be able to invoke receive of target through forwarder: invokes forwarder', async () => {
      await expect(
        admin.sendTransaction({
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).changeEtherBalances([admin.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should be able to call the function of admin: invokes forwarder method', async () => {
      let forwarderBalance = await ethers.provider.getBalance(forwarder.address);

      // overloaded method in forwarder is invoked here
      let tx;
      await expect(async () => (tx = forwarder.withdrawAll())).changeEtherBalances(
        [admin.address, forwarder.address, target.address],
        [forwarderBalance, BigNumber.from(0).sub(forwarderBalance), 0]
      );

      expect(tx).not.emit(target, 'TargetWithdrawn');
      expect(tx).emit(forwarder, 'ForwarderWithdrawn').withArgs(admin.address, forwarderBalance);
    });
  });

  describe('Calls from unauthorized user', async () => {
    it('Should not be able to call foo function', async () => {});
    it('Should not be able to call payable foo function, with fund from caller account', async () => {});
    it('Should not be able to call payable foo function, with fund from forwarder account', async () => {});
    it("Should not be able to call function of target, that has the same name with admin's", async () => {});
    it('Should not be able to call fallback', async () => {});
    it('Should not be able to call receive', async () => {});
    it('Should not be able to call the function of admin', async () => {});
  });
});
