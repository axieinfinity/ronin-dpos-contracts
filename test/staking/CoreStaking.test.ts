import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { MockManager, MockManager__factory } from '../../src/types';

const EPS = 1;

let deployer: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let manager: MockManager;

const local = {
  accumulatedRewardForA: BigNumber.from(0),
  accumulatedRewardForB: BigNumber.from(0),
  claimableRewardForA: BigNumber.from(0),
  claimableRewardForB: BigNumber.from(0),
  recordReward: async function (reward: BigNumberish) {
    const totalStaked = await manager.totalBalance();
    const stakingAmountA = await manager.balanceOf(userA.address);
    const stakingAmountB = await manager.balanceOf(userB.address);
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
    const userReward = await manager.getTotalReward(userA.address);
    expect(
      userReward.sub(local.accumulatedRewardForA).abs().lte(EPS),
      `invalid user reward for A expected=${local.accumulatedRewardForA.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await manager.getClaimableReward(userA.address);
    expect(
      claimableReward.sub(local.claimableRewardForA).abs().lte(EPS),
      `invalid claimable reward for A expected=${local.claimableRewardForA.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
  {
    const userReward = await manager.getTotalReward(userB.address);
    expect(
      userReward.sub(local.accumulatedRewardForB).abs().lte(EPS),
      `invalid user reward for B expected=${local.accumulatedRewardForB.toString()} actual=${userReward}`
    ).to.be.true;
    const claimableReward = await manager.getClaimableReward(userB.address);
    expect(
      claimableReward.sub(local.claimableRewardForB).abs().lte(EPS),
      `invalid claimable reward for B expected=${local.claimableRewardForB.toString()} actual=${claimableReward}`
    ).to.be.true;
  }
};

describe('Core Staking test', () => {
  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    manager = await new MockManager__factory(deployer).deploy();
    await network.provider.send('evm_setAutomine', [false]);
    local.reset();
  });

  it('Should be able to stake/unstake and get right total reward for a successful epoch', async () => {
    await manager.stake(userA.address, 100);
    await manager.stake(userB.address, 100);
    await network.provider.send('evm_mine');

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.unstake(userA.address, 200);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await manager.commitRewardPool();
    await manager.endEpoch();
    await network.provider.send('evm_mine');
    local.commitRewardPool();
    await expectLocalCalculationRight();
  });

  it('Should be able to stake/unstake and get right total reward for a slashed epoch', async () => {
    await manager.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
    await local.recordReward(0);

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.stake(userA.address, 300);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await manager.recordReward(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    await manager.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await manager.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await manager.commitRewardPool();
    await manager.endEpoch();
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
  });

  it('Should be able to stake/unstake/claim and get right total reward for a slashed epoch again', async () => {
    await manager.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await manager.claimReward(userA.address);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.claimRewardForA();
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.stake(userA.address, 300);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await manager.recordReward(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    await manager.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await manager.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await manager.claimReward(userB.address);
    await manager.commitRewardPool();
    await manager.endEpoch();
    await network.provider.send('evm_mine');
    local.claimRewardForB();
    await expectLocalCalculationRight();
  });

  it('Should be able to get right claimable reward for the committed epoch', async () => {
    await manager.recordReward(1000);
    await manager.commitRewardPool();
    await manager.endEpoch();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.commitRewardPool();
    await expectLocalCalculationRight();

    await manager.claimReward(userA.address);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.claimRewardForA();
    await expectLocalCalculationRight();

    await manager.claimReward(userA.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    console.log(local, await ethers.provider.getBlockNumber());
    await expectLocalCalculationRight();

    await manager.claimReward(userB.address);
    await manager.commitRewardPool();
    await manager.endEpoch();
    await network.provider.send('evm_mine');
    local.claimRewardForB();
    local.commitRewardPool();
    await expectLocalCalculationRight();
  });

  it('Should be able to get right claimable reward test', async () => {
    console.log(0, local);
    await manager.stake(userA.address, 100);
    await network.provider.send('evm_mine');

    console.log(1, local);
    await manager.stake(userA.address, 300);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    console.log(2, local);
    await manager.stake(userB.address, 200);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await manager.unstake(userB.address, 200);
    await manager.unstake(userA.address, 400);
    await manager.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    console.log(3, local);
    await manager.claimReward(userA.address);
    await manager.claimReward(userB.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();

    console.log(4, local);
  });
});
