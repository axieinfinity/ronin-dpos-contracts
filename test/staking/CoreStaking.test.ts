import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { MockStaking, MockStaking__factory } from '../../src/types';

const EPS = 1;
const poolAddr = ethers.constants.AddressZero;

let deployer: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let stakingContract: MockStaking;

const local = {
  accumulatedRewardForA: BigNumber.from(0),
  accumulatedRewardForB: BigNumber.from(0),
  claimableRewardForA: BigNumber.from(0),
  claimableRewardForB: BigNumber.from(0),
  recordReward: async function (reward: BigNumberish) {
    const totalStaked = await stakingContract.totalBalance(poolAddr);
    const stakingAmountA = await stakingContract.balanceOf(poolAddr, userA.address);
    const stakingAmountB = await stakingContract.balanceOf(poolAddr, userB.address);
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
    const userReward = await stakingContract.getTotalReward(poolAddr, userA.address);
    expect(
      userReward.sub(local.accumulatedRewardForA).abs().lte(EPS),
      `invalid user reward for A expected=${local.accumulatedRewardForA.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await stakingContract.getClaimableReward(poolAddr, userA.address);
    expect(
      claimableReward.sub(local.claimableRewardForA).abs().lte(EPS),
      `invalid claimable reward for A expected=${local.claimableRewardForA.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
  {
    const userReward = await stakingContract.getTotalReward(poolAddr, userB.address);
    expect(
      userReward.sub(local.accumulatedRewardForB).abs().lte(EPS),
      `invalid user reward for B expected=${local.accumulatedRewardForB.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await stakingContract.getClaimableReward(poolAddr, userB.address);
    expect(
      claimableReward.sub(local.claimableRewardForB).abs().lte(EPS),
      `invalid claimable reward for B expected=${local.claimableRewardForB.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
};

describe('Core Staking test', () => {
  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
    await network.provider.send('evm_setAutomine', [false]);
    local.reset();
  });

  it('Should work properly with staking actions occurring sequentially for a normal period', async () => {
    await stakingContract.stake(userA.address, 100);
    await stakingContract.stake(userB.address, 100);
    await network.provider.send('evm_mine');

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.unstake(userA.address, 200);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    local.commitRewardPool();
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions occurring sequentially for a slashed period', async () => {
    await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
    await local.recordReward(0);

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.stake(userA.address, 300);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    await stakingContract.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await stakingContract.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions occurring sequentially for a slashed period again', async () => {
    await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.claimRewardForA();
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.stake(userA.address, 300);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    await stakingContract.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await stakingContract.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userB.address);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    local.claimRewardForB();
    await expectLocalCalculationRight();
  });

  it('Should be able to calculate right reward after claiming', async () => {
    await stakingContract.recordRewardForDelegators(1000);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.claimRewardForA();
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userB.address);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    local.claimRewardForB();
    local.commitRewardPool();
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions from multi-users occurring in the same block', async () => {
    await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');

    await stakingContract.stake(userA.address, 300);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.stake(userB.address, 200);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.unstake(userB.address, 200);
    await stakingContract.unstake(userA.address, 400);
    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();

    await stakingContract.unstake(userA.address, 200);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions occurring in the same block', async () => {
    await stakingContract.stake(userA.address, 100);
    await stakingContract.unstake(userA.address, 100);
    await stakingContract.stake(userA.address, 100);
    await stakingContract.unstake(userA.address, 100);
    await stakingContract.stake(userB.address, 200);
    await stakingContract.unstake(userB.address, 200);
    await stakingContract.stake(userB.address, 200);
    await stakingContract.unstake(userB.address, 200);
    await stakingContract.stake(userB.address, 200);
    await stakingContract.stake(userA.address, 100);
    await stakingContract.unstake(userA.address, 100);
    await stakingContract.unstake(userB.address, 200);
    await stakingContract.stake(userB.address, 200);
    await stakingContract.unstake(userA.address, 100);
    await stakingContract.stake(userA.address, 100);
    await stakingContract.unstake(userB.address, 200);
    await stakingContract.recordRewardForDelegators(1000);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await stakingContract.recordRewardForDelegators(1000);
    await stakingContract.commitRewardPool();
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userA.address);
    await stakingContract.claimReward(userB.address);
    await stakingContract.claimReward(userB.address);
    await stakingContract.claimReward(userB.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();
  });
});
