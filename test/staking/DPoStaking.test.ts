import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { DPoStaking, DPoStaking__factory, TransparentUpgradeableProxy__factory } from '../../src/types';
import { MockValidatorSet__factory } from '../../src/types/factories/MockValidatorSet__factory';
import { MockValidatorSet } from '../../src/types/MockValidatorSet';

const EPS = 1;

let poolAddr: SignerWithAddress;
let otherPoolAddr: SignerWithAddress;
let deployer: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let validatorContract: MockValidatorSet;
let stakingContract: DPoStaking;
let validatorCandidates: SignerWithAddress[];

const local = {
  accumulatedRewardForA: BigNumber.from(0),
  accumulatedRewardForB: BigNumber.from(0),
  claimableRewardForA: BigNumber.from(0),
  claimableRewardForB: BigNumber.from(0),
  recordReward: async function (reward: BigNumberish) {
    const totalStaked = await stakingContract.totalBalance(poolAddr.address);
    const stakingAmountA = await stakingContract.balanceOf(poolAddr.address, userA.address);
    const stakingAmountB = await stakingContract.balanceOf(poolAddr.address, userB.address);
    this.accumulatedRewardForA = this.accumulatedRewardForA.add(
      BigNumber.from(reward).mul(stakingAmountA).div(totalStaked)
    );
    this.accumulatedRewardForB = this.accumulatedRewardForB.add(
      BigNumber.from(reward).mul(stakingAmountB).div(totalStaked)
    );
  },
  commitRewardPool: function () {
    this.claimableRewardForA = this.accumulatedRewardForA;
    this.claimableRewardForB = this.accumulatedRewardForB;
  },
  slash: function () {
    this.accumulatedRewardForA = this.claimableRewardForA;
    this.accumulatedRewardForB = this.claimableRewardForB;
  },
  reset: function () {
    this.claimableRewardForA = BigNumber.from(0);
    this.claimableRewardForB = BigNumber.from(0);
    this.accumulatedRewardForA = BigNumber.from(0);
    this.accumulatedRewardForB = BigNumber.from(0);
  },
  claimRewardForA: function () {
    this.accumulatedRewardForA = this.accumulatedRewardForA.sub(this.claimableRewardForA);
    this.claimableRewardForA = BigNumber.from(0);
  },
  claimRewardForB: function () {
    this.accumulatedRewardForB = this.accumulatedRewardForB.sub(this.claimableRewardForB);
    this.claimableRewardForB = BigNumber.from(0);
  },
};

const expectLocalCalculationRight = async () => {
  {
    const userReward = await stakingContract.getTotalReward(poolAddr.address, userA.address);
    expect(
      userReward.sub(local.accumulatedRewardForA).abs().lte(EPS),
      `invalid user reward for A expected=${local.accumulatedRewardForA.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await stakingContract.getClaimableReward(poolAddr.address, userA.address);
    expect(
      claimableReward.sub(local.claimableRewardForA).abs().lte(EPS),
      `invalid claimable reward for A expected=${local.claimableRewardForA.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
  {
    const userReward = await stakingContract.getTotalReward(poolAddr.address, userB.address);
    expect(
      userReward.sub(local.accumulatedRewardForB).abs().lte(EPS),
      `invalid user reward for B expected=${local.accumulatedRewardForB.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await stakingContract.getClaimableReward(poolAddr.address, userB.address);
    expect(
      claimableReward.sub(local.claimableRewardForB).abs().lte(EPS),
      `invalid claimable reward for B expected=${local.claimableRewardForB.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
};

const minValidatorBalance = BigNumber.from(2);

describe('DPoStaking test', () => {
  before(async () => {
    [deployer, proxyAdmin, userA, userB, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 3);
    const nonce = await deployer.getTransactionCount();
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    validatorContract = await new MockValidatorSet__factory(deployer).deploy(
      stakingContractAddr,
      ethers.constants.AddressZero,
      10,
      2
    );
    await validatorContract.deployed();
    const logicContract = await new DPoStaking__factory(deployer).deploy();
    await logicContract.deployed();
    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        validatorContract.address,
        governanceAdmin.address,
        50,
        minValidatorBalance,
      ])
    );
    await proxyContract.deployed();
    stakingContract = DPoStaking__factory.connect(proxyContract.address, deployer);
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  describe('Validator candidate test', () => {
    it('Should not be able to propose validator with insufficient amount', async () => {
      await expect(stakingContract.proposeValidator(userA.address, userA.address, 1)).revertedWith(
        'StakingManager: insufficient amount'
      );
    });

    it('Should be able to propose validator with sufficient amount', async () => {
      for (let i = 1; i < validatorCandidates.length; i++) {
        const candidate = validatorCandidates[i];
        await stakingContract.connect(candidate).proposeValidator(
          candidate.address,
          candidate.address,
          1, // 0.01%
          { value: minValidatorBalance }
        );
      }

      poolAddr = validatorCandidates[1];
      otherPoolAddr = validatorCandidates[2];
      expect(await stakingContract.totalBalance(poolAddr.address)).eq(minValidatorBalance);
    });

    it('Should not be able to propose validator again', async () => {
      await expect(
        stakingContract.connect(poolAddr).proposeValidator(poolAddr.address, poolAddr.address, 0)
      ).revertedWith('StakingManager: query for existed candidate');
    });

    it('Should not be able to stake with empty value', async () => {
      await expect(stakingContract.stake(poolAddr.address, { value: 0 })).revertedWith(
        'StakingManager: query with empty value'
      );
    });

    it('Should not be able to call stake/unstake when the method is not the candidate admin', async () => {
      await expect(stakingContract.stake(poolAddr.address, { value: 1 })).revertedWith(
        'StakingManager: user is not the candidate admin'
      );
      await expect(stakingContract.unstake(poolAddr.address, 1)).revertedWith(
        'StakingManager: user is not the candidate admin'
      );
    });

    it('Should be able to stake/unstake as a validator', async () => {
      await stakingContract.connect(poolAddr).stake(poolAddr.address, { value: 1 });
      expect(await stakingContract.totalBalance(poolAddr.address)).eq(minValidatorBalance.add(1));
      await stakingContract.connect(poolAddr).unstake(poolAddr.address, 1);
      expect(await stakingContract.totalBalance(poolAddr.address)).eq(minValidatorBalance);
    });

    it('Should be not able to unstake with the balance left is not larger than the minimum balance threshold', async () => {
      await expect(stakingContract.connect(poolAddr).unstake(poolAddr.address, 2)).revertedWith(
        'StakingManager: invalid staked amount left'
      );
    });
  });

  describe('Delegator test', () => {
    it('Should not be able to delegate with empty value', async () => {
      await expect(stakingContract.delegate(otherPoolAddr.address)).revertedWith(
        'StakingManager: query with empty value'
      );
    });

    it('Should not be able to delegate/undelegate when the method caller is the candidate owner', async () => {
      await expect(stakingContract.connect(poolAddr).delegate(poolAddr.address, { value: 1 })).revertedWith(
        'StakingManager: method caller must not be the candidate admin'
      );
      await expect(stakingContract.connect(poolAddr).undelegate(poolAddr.address, 1)).revertedWith(
        'StakingManager: method caller must not be the candidate admin'
      );
    });

    it('Should be able to delegate/undelegate', async () => {
      await stakingContract.connect(userA).delegate(otherPoolAddr.address, { value: 1 });
      await stakingContract.connect(userB).delegate(otherPoolAddr.address, { value: 1 });
      expect(await stakingContract.totalBalance(otherPoolAddr.address)).eq(minValidatorBalance.add(2));
      await stakingContract.connect(userA).undelegate(otherPoolAddr.address, 1);
      expect(await stakingContract.totalBalance(otherPoolAddr.address)).eq(minValidatorBalance.add(1));
    });
  });

  describe('Reward Calculation test', () => {
    before(async () => {
      poolAddr = validatorCandidates[0];
      await stakingContract.connect(governanceAdmin).setMinValidatorBalance(0);
      await stakingContract.connect(poolAddr).proposeValidator(poolAddr.address, poolAddr.address, 0, { value: 0 });

      await network.provider.send('evm_setAutomine', [false]);
    });

    after(async () => {
      await network.provider.send('evm_setAutomine', [true]);
    });

    it('Should work properly with staking actions occurring sequentially for a normal period', async () => {
      await stakingContract.connect(userA).delegate(poolAddr.address, { value: 100 });
      await stakingContract.connect(userB).delegate(poolAddr.address, { value: 100 });
      await stakingContract.connect(userA).delegate(otherPoolAddr.address, { value: 100 });
      await network.provider.send('evm_mine');

      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await network.provider.send('evm_mine');
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await stakingContract.connect(userA).delegate(poolAddr.address, { value: 200 });
      await network.provider.send('evm_mine');
      await expectLocalCalculationRight();

      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await stakingContract.connect(userA).undelegate(poolAddr.address, 200);
      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await stakingContract.connect(userA).delegate(poolAddr.address, { value: 200 });
      await network.provider.send('evm_mine');
      await local.recordReward(0);
      await expectLocalCalculationRight();

      await validatorContract.settledReward([poolAddr.address, otherPoolAddr.address]);
      await validatorContract.endPeriod();
      await network.provider.send('evm_mine');
      local.commitRewardPool();
      await expectLocalCalculationRight();
    });

    it('Should work properly with staking actions occurring sequentially for a slashed period', async () => {
      await stakingContract.connect(userA).delegate(poolAddr.address, { value: 100 });
      await network.provider.send('evm_mine');
      await expectLocalCalculationRight();

      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await stakingContract.connect(userA).delegate(poolAddr.address, { value: 300 });
      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      await expectLocalCalculationRight();

      await validatorContract.slashMisdemeanor(poolAddr.address);
      await network.provider.send('evm_mine');
      local.slash();
      await expectLocalCalculationRight();

      await validatorContract.connect(poolAddr).depositReward({ value: 0 });
      await network.provider.send('evm_mine');
      await local.recordReward(0);
      await expectLocalCalculationRight();

      await network.provider.send('evm_mine');
      await network.provider.send('evm_mine');
      await network.provider.send('evm_mine');
      await network.provider.send('evm_mine');

      await stakingContract.connect(userA).undelegate(poolAddr.address, 300);
      await network.provider.send('evm_mine');
      await stakingContract.connect(userA).undelegate(poolAddr.address, 100);
      await network.provider.send('evm_mine');
      await expectLocalCalculationRight();

      await validatorContract.settledReward([poolAddr.address]);
      await validatorContract.endPeriod();
      await network.provider.send('evm_mine');
      await expectLocalCalculationRight();
    });
  });
});
