import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  VaultForwarder,
  VaultForwarder__factory,
  MockForwarderTarget,
  MockForwarderTarget__factory,
} from '../../../src/types';
import { DEFAULT_ADDRESS, TARGET_ROLE, DEFAULT_ADMIN_ROLE, MODERATOR_ROLE } from '../../../src/utils';
import { accessControlRevertStr, calculateAddress } from '../helpers/utils';
import { parseEther } from 'ethers/lib/utils';

let deployer: SignerWithAddress;
let admin: SignerWithAddress;
let moderator: SignerWithAddress;
let unauthorized: SignerWithAddress;
let forwarder: VaultForwarder;
let targets: MockForwarderTarget[] = [];
let target: MockForwarderTarget;
let localData: BigNumber;

describe('Vault forwarder', () => {
  before(async () => {
    [deployer, admin, moderator, unauthorized] = await ethers.getSigners();

    let nonce = await ethers.provider.getTransactionCount(deployer.address);
    let forwarderAddress = calculateAddress(deployer.address, nonce + 2).address;

    localData = BigNumber.from(0);
    target = await new MockForwarderTarget__factory(deployer).deploy(forwarderAddress, localData);
    targets.push(target);
    targets.push(await new MockForwarderTarget__factory(deployer).deploy(forwarderAddress, localData));
    forwarder = await new VaultForwarder__factory(deployer).deploy([target.address], admin.address, DEFAULT_ADDRESS);

    await deployer.sendTransaction({
      to: forwarderAddress,
      value: parseEther('1.0'),
    });

    expect(forwarder.address).eq(forwarderAddress);
  });

  describe('Configuration test', async () => {
    it('Should the forward config the target correctly', async () => {
      expect(await forwarder.getRoleMemberCount(TARGET_ROLE)).eq(1);
      expect(await forwarder.getRoleMember(TARGET_ROLE, 0)).eq(target.address);
    });
    it('Should the forward config the admin correctly', async () => {
      expect(await forwarder.getRoleMemberCount(DEFAULT_ADMIN_ROLE)).eq(1);
      expect(await forwarder.getRoleMember(DEFAULT_ADMIN_ROLE, 0)).eq(admin.address);
    });
  });

  describe('Access grant', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, admin);
    });
    it('Should the admin be able to grant moderator role', async () => {
      await forwarder.grantRole(MODERATOR_ROLE, moderator.address);
      expect(await forwarder.hasRole(MODERATOR_ROLE, moderator.address)).eq(true);
      expect(await forwarder.getRoleMemberCount(MODERATOR_ROLE)).eq(2);
      expect(await forwarder.getRoleMember(MODERATOR_ROLE, 0)).eq(DEFAULT_ADDRESS);
      expect(await forwarder.getRoleMember(MODERATOR_ROLE, 1)).eq(moderator.address);
    });
    it('Should the admin be able to revoke moderator role', async () => {
      await forwarder.revokeRole(MODERATOR_ROLE, DEFAULT_ADDRESS);
      expect(await forwarder.getRoleMemberCount(MODERATOR_ROLE)).eq(1);
      expect(await forwarder.getRoleMember(MODERATOR_ROLE, 0)).eq(moderator.address);
    });
  });

  describe('Calls from moderator user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, moderator);
      target = MockForwarderTarget__factory.connect(target.address, moderator);
    });

    it('Should be able to call non-payable foo function', async () => {
      await forwarder.functionCall(target.address, target.interface.encodeFunctionData('foo', [2]), 0);
      expect(await target.data()).eq(2);
    });

    it('Should be able to call payable foo function, with fund from forwarder account', async () => {
      expect(
        await forwarder.functionCall(target.address, target.interface.encodeFunctionData('fooPayable', [4]), 200)
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [0, -200, 200]);
      expect(await target.data()).eq(4);
      expect(await target.getBalance()).eq(200);
    });

    it('Should the revert message is thrown from target contract', async () => {
      await expect(
        forwarder.functionCall(target.address, target.interface.encodeFunctionData('fooRevert'), 0)
      ).revertedWith('MockForwarderContract: revert intentionally');
    });

    it('Should the silent revert message is thrown from forwarder contract', async () => {
      await expect(forwarder.functionCall(target.address, target.interface.encodeFunctionData('fooSilentRevert'), 0))
        .reverted;
    });

    it('Should the custom error is thrown from forwarder contract', async () => {
      await expect(
        forwarder.functionCall(target.address, target.interface.encodeFunctionData('fooCustomErrorRevert'), 0)
      ).revertedWithCustomError(target, 'ErrIntentionally');
    });

    it("Should be able to call function of target, that has the same name with admin's function", async () => {
      await expect(
        forwarder.functionCall(target.address, target.interface.encodeFunctionData('withdrawAll'), 0)
      ).changeEtherBalances([forwarder.address, target.address, moderator.address], [200, -200, 0]);
    });

    it('Implicit call fallback of target', async () => {
      await expect(forwarder.functionCall(target.address, '0xdeadbeef', 0)).revertedWith(
        'MockForwardTarget: hello from fallback'
      );
    });

    it('Fallback: invokes forwarder', async () => {
      await expect(
        moderator.sendTransaction({
          data: '0xdeadbeef',
          to: forwarder.address,
          value: 200,
        })
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Receive: invokes forwarder', async () => {
      await expect(
        moderator.sendTransaction({
          to: forwarder.address,
          value: 200,
        })
      ).changeEtherBalances([moderator.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should not be able to call the function of admin', async () => {
      await expect(forwarder.withdrawAll()).revertedWith(accessControlRevertStr(moderator.address, DEFAULT_ADMIN_ROLE));
    });
  });

  describe('Target tests', async () => {
    it('Should not be able to call to non-target-role contract', async () => {
      await expect(
        forwarder
          .connect(moderator)
          .functionCall(unauthorized.address, target.interface.encodeFunctionData('foo', [2]), 0)
      ).revertedWith(accessControlRevertStr(unauthorized.address, TARGET_ROLE));
    });

    it('Should non-admin not be able to add more target', async () => {
      await expect(forwarder.connect(moderator).grantRole(TARGET_ROLE, targets[1].address)).revertedWith(
        accessControlRevertStr(moderator.address, DEFAULT_ADMIN_ROLE)
      );
    });

    it('Should admin be able to add more target', async () => {
      await forwarder.connect(admin).grantRole(TARGET_ROLE, targets[1].address);
      expect(await forwarder.getRoleMemberCount(TARGET_ROLE)).eq(2);
      expect(await forwarder.getRoleMember(TARGET_ROLE, 1)).eq(targets[1].address);
    });

    it('Should the new target can be called', async () => {
      await forwarder
        .connect(moderator)
        .functionCall(targets[1].address, target.interface.encodeFunctionData('foo', [92]), 0);
      expect(await targets[1].data()).eq(92);
    });
  });

  describe('Calls from admin user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, admin);
      target = MockForwarderTarget__factory.connect(target.address, admin);
    });

    it('Should not be able to call forwarding method', async () => {
      await expect(
        forwarder.functionCall(target.address, target.interface.encodeFunctionData('foo', [2]), 0)
      ).revertedWith(accessControlRevertStr(admin.address, MODERATOR_ROLE));
    });

    it('Fallback: invokes forwarder', async () => {
      await expect(
        admin.sendTransaction({
          data: '0xdeadbeef',
          to: forwarder.address,
          value: 200,
        })
      ).changeEtherBalances([admin.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Receive: invokes forwarder', async () => {
      let tx;
      await expect(
        async () =>
          (tx = admin.sendTransaction({
            to: forwarder.address,
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
      await expect(tx).emit(forwarder, 'ForwarderRONWithdrawn').withArgs(admin.address, forwarderBalance);
    });
  });

  describe('Calls from unauthorized user', async () => {
    before(async () => {
      forwarder = VaultForwarder__factory.connect(forwarder.address, unauthorized);
      target = MockForwarderTarget__factory.connect(target.address, unauthorized);
    });

    it('Should not be able to call forwarding method', async () => {
      await expect(
        forwarder.functionCall(target.address, target.interface.encodeFunctionData('foo', [2]), 0)
      ).revertedWith(accessControlRevertStr(unauthorized.address, MODERATOR_ROLE));
    });

    it('Fallback: accept incoming token', async () => {
      await expect(
        unauthorized.sendTransaction({
          data: '0xdeadbeef',
          to: forwarder.address,
          value: 200,
        })
      ).changeEtherBalances([unauthorized.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Receive: accept incoming token', async () => {
      await expect(
        unauthorized.sendTransaction({
          to: forwarder.address,
          value: 200,
        })
      ).changeEtherBalances([unauthorized.address, forwarder.address, target.address], [-200, 200, 0]);
    });

    it('Should not be able to call the overloaded method', async () => {
      await expect(forwarder.withdrawAll()).revertedWith(
        accessControlRevertStr(unauthorized.address, DEFAULT_ADMIN_ROLE)
      );
    });
  });
});
