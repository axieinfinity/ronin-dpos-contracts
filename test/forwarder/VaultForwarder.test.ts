import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  VaultForwarder,
  VaultForwarder__factory,
  MockForwarderTarget,
  MockForwarderTarget__factory,
} from '../../src/types';
import { DEFAULT_ADDRESS, FORWARDER_ADMIN_SLOT, MODERATOR_ROLE, FORWARDER_TARGET_SLOT } from '../../src/utils';
import { calculateAddress } from '../helpers/utils';
import { parseEther } from 'ethers/lib/utils';

let deployer: SignerWithAddress;
let admin: SignerWithAddress;
let moderator: SignerWithAddress;
let unauthorized: SignerWithAddress;
let forwarder: VaultForwarder;
let targetBehindForwarder: MockForwarderTarget;
let target: MockForwarderTarget;
let localData: BigNumber;

describe('Vault forwarder', () => {
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
    forwarder = await new VaultForwarder__factory(deployer).deploy(target.address, admin.address);
    expect(forwarder.address).eq(forwarderAddress);
  });

  describe('Configuration test', async () => {
    it('Should the forward config the target correctly', async () => {
      expect(await network.provider.send('eth_getStorageAt', [forwarder.address, FORWARDER_TARGET_SLOT])).eq(
        ['0x', '0'.repeat(24), target.address.toLocaleLowerCase().slice(2)].join('')
      );
    });
    it('Should the forward config the admin correctly', async () => {
      expect(await network.provider.send('eth_getStorageAt', [forwarder.address, FORWARDER_ADMIN_SLOT])).eq(
        ['0x', '0'.repeat(24), admin.address.toLocaleLowerCase().slice(2)].join('')
      );
    });
  });

  describe('Access grant', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, admin);
    });
    it('Should the admin be able to grant moderator role', async () => {
      await forwarder.grantRole(MODERATOR_ROLE, moderator.address);
      expect(await forwarder.hasRole(MODERATOR_ROLE, moderator.address)).eq(true);
    });
  });

  describe('Calls from moderator user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, moderator);
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

    it('Should the revert message is thrown from target contract', async () => {
      await expect(targetBehindForwarder.fooRevert()).revertedWith('MockForwarderContract: revert intentionally');
    });

    it('Should the silent revert message is thrown from forwarder contract', async () => {
      await expect(targetBehindForwarder.fooSilentRevert()).revertedWith('Forwarder: reverted silently');
    });

    it("Should be able to call function of target, that has the same name with admin's function", async () => {
      await expect(targetBehindForwarder.withdrawAll()).changeEtherBalances(
        [forwarder.address, target.address],
        [300, -300]
      );
    });

    it('Fallback: invokes target', async () => {
      await expect(
        moderator.sendTransaction({
          data: '0xdeadbeef',
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).revertedWith('MockForwardTarget: hello from fallback');
    });

    it('Receive: invokes forwarder', async () => {
      await expect(
        moderator.sendTransaction({
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should not be able to call the function of admin', async () => {
      // overloaded method in target is invoked here
      let tx;
      await expect(async () => (tx = forwarder.withdrawAll())).changeEtherBalances(
        [moderator.address, forwarder.address, target.address],
        [0, 0, 0]
      );

      await expect(tx)
        .emit(target, 'TargetWithdrawn')
        .withArgs(moderator.address, forwarder.address, forwarder.address);
      await expect(tx).not.emit(forwarder, 'ForwarderWithdrawn');
    });
  });

  describe('Calls from admin user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, admin);
      target = MockForwarderTarget__factory.connect(target.address, admin);
      targetBehindForwarder = MockForwarderTarget__factory.connect(forwarder.address, admin);
    });

    it('Should not be able to call non-payable foo function', async () => {
      await expect(targetBehindForwarder.foo(12)).revertedWith('Forwarder: unauthorized call');
      expect(await target.data()).not.eq(12);
    });

    it('Should not be able to call non-payable foo function by force `functionCall`', async () => {
      await expect(forwarder.functionCall(target.interface.encodeFunctionData('foo', [12]), 0)).revertedWith(
        'Forwarder: unauthorized call'
      );
    });

    it('Should not be able to call payable foo function, with fund from forwarder account', async () => {
      await expect(forwarder.functionCall(target.interface.encodeFunctionData('fooPayable', [13]), 300)).rejectedWith(
        'Forwarder: unauthorized call'
      );
    });

    it('Fallback: invokes forwarder', async () => {
      await expect(
        admin.sendTransaction({
          data: '0xdeadbeef',
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).revertedWith('Forwarder: unauthorized call');
    });

    it('Receive: invokes forwarder', async () => {
      let tx;
      await expect(
        async () =>
          (tx = admin.sendTransaction({
            to: targetBehindForwarder.address,
            value: 200,
          }))
      ).changeEtherBalances([admin.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should be able to call the admin function of forwarder', async () => {
      let forwarderBalance = await ethers.provider.getBalance(forwarder.address);

      // overloaded method in forwarder is invoked here
      let tx;
      await expect(async () => (tx = forwarder.withdrawAll())).changeEtherBalances(
        [admin.address, forwarder.address, target.address],
        [forwarderBalance, BigNumber.from(0).sub(forwarderBalance), 0]
      );

      await expect(tx).not.emit(target, 'TargetWithdrawn');
      await expect(tx).emit(forwarder, 'ForwarderWithdrawn').withArgs(admin.address, forwarderBalance);
    });
  });

  describe('Calls from unauthorized user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, unauthorized);
      target = MockForwarderTarget__factory.connect(target.address, unauthorized);
      targetBehindForwarder = MockForwarderTarget__factory.connect(forwarder.address, unauthorized);
    });

    it('Should not be able to call foo function', async () => {
      await expect(targetBehindForwarder.foo(22)).revertedWith('Forwarder: unauthorized call');
      await expect(forwarder.functionCall(target.interface.encodeFunctionData('foo', [22]), 0)).revertedWith(
        'Forwarder: unauthorized call'
      );
    });

    it('Should not be able to call payable foo function, with fund from caller account', async () => {
      await expect(targetBehindForwarder.fooPayable(22, { value: 100 })).revertedWith('Forwarder: unauthorized call');
    });

    it('Should not be able to call payable foo function, with fund from forwarder account', async () => {
      await expect(forwarder.functionCall(target.interface.encodeFunctionData('fooPayable', [22]), 100)).revertedWith(
        'Forwarder: unauthorized call'
      );
    });

    it('Fallback: revert', async () => {
      await expect(
        unauthorized.sendTransaction({
          data: '0xdeadbeef',
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).revertedWith('Forwarder: unauthorized call');
    });

    it('Receive: accept incoming token', async () => {
      await expect(
        unauthorized.sendTransaction({
          to: targetBehindForwarder.address,
          value: 200,
        })
      ).changeEtherBalances([unauthorized.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should not be able to call the overloaded method', async () => {
      await expect(forwarder.withdrawAll()).revertedWith('Forwarder: unauthorized call');
    });

    it('Should not be able to call the function of admin', async () => {
      await expect(forwarder.withdrawAll()).revertedWith('Forwarder: unauthorized call');
    });

    it('Should not be able to call the exposed methods', async () => {
      await expect(forwarder.changeForwarderAdmin(DEFAULT_ADDRESS)).revertedWith('Forwarder: unauthorized call');
      await expect(forwarder.changeTargetTo(DEFAULT_ADDRESS)).revertedWith('Forwarder: unauthorized call');
    });
  });
});
