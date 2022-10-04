import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';

import { MockStaking, MockStaking__factory } from '../../src/types';
import * as StakingContract from '../helpers/staking';

const EPS = 1;
const MASK = BigNumber.from(10).pow(18);
const poolAddr = ethers.constants.AddressZero;

let deployer: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let stakingContract: MockStaking;

const local = {
  balanceA: BigNumber.from(0),
  balanceB: BigNumber.from(0),
  accumulatedRewardForA: BigNumber.from(0),
  accumulatedRewardForB: BigNumber.from(0),
  claimableRewardForA: BigNumber.from(0),
  claimableRewardForB: BigNumber.from(0),
  aRps: BigNumber.from(0),
  settledARps: BigNumber.from(0),
  syncBalance: async function () {
    this.balanceA = await stakingContract.balanceOf(poolAddr, userA.address);
    this.balanceB = await stakingContract.balanceOf(poolAddr, userB.address);
  },
  recordReward: async function (reward: BigNumberish) {
    const totalStaked = await stakingContract.totalBalance(poolAddr);
    await this.syncBalance();
    this.accumulatedRewardForA = this.accumulatedRewardForA.add(
      BigNumber.from(reward).mul(this.balanceA).div(totalStaked)
    );
    this.accumulatedRewardForB = this.accumulatedRewardForB.add(
      BigNumber.from(reward).mul(this.balanceB).div(totalStaked)
    );
    this.aRps = this.aRps.add(BigNumber.from(reward).mul(MASK).div(totalStaked));
  },
  settledPools: function () {
    this.claimableRewardForA = this.accumulatedRewardForA;
    this.claimableRewardForB = this.accumulatedRewardForB;
    this.settledARps = this.aRps;
  },
  slash: function () {
    this.accumulatedRewardForA = this.claimableRewardForA;
    this.accumulatedRewardForB = this.claimableRewardForB;
    this.aRps = this.settledARps;
  },
  reset: function () {
    this.claimableRewardForA = BigNumber.from(0);
    this.claimableRewardForB = BigNumber.from(0);
    this.accumulatedRewardForA = BigNumber.from(0);
    this.accumulatedRewardForB = BigNumber.from(0);
    this.aRps = BigNumber.from(0);
    this.settledARps = BigNumber.from(0);
    this.balanceA = BigNumber.from(0);
    this.balanceB = BigNumber.from(0);
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

describe('Reward Calculation test', () => {
  let tx: ContractTransaction;
  const txs: ContractTransaction[] = [];

  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
    await network.provider.send('evm_setAutomine', [false]);
    local.reset();
  });

  after(async () => {
    await network.provider.send('evm_setAutomine', [true]);
  });

  it('Should work properly with staking actions occurring sequentially for a normal period', async () => {
    txs[0] = await stakingContract.stake(userA.address, 100);
    txs[1] = await stakingContract.stake(userB.address, 100);
    await network.provider.send('evm_mine');
    await expect(txs[0]!).emit(stakingContract, 'PendingRewardUpdated').withArgs(poolAddr, userA.address, 0, 0);
    await expect(txs[1]!).emit(stakingContract, 'PendingRewardUpdated').withArgs(poolAddr, userB.address, 0, 0);

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 1000, local.aRps.mul(local.balanceA).div(MASK));
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.unstake(userA.address, 200);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 1750, local.aRps.mul(local.balanceA).div(MASK));
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK));
    await expectLocalCalculationRight();

    tx = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(tx!, [poolAddr], [local.aRps]);
    local.settledPools();
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions occurring sequentially for a slashed period', async () => {
    txs[0] = await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, local.balanceA, 2250, local.aRps);
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK));

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);

    txs[0] = await stakingContract.stake(userA.address, 300);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 3850, local.aRps.mul(local.balanceA).div(MASK));
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    txs[0] = await stakingContract.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK));
    txs[0] = await stakingContract.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK));

    tx = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(tx!, [poolAddr], [local.aRps]);
  });

  it('Should work properly with staking actions occurring sequentially for a slashed period again', async () => {
    txs[0] = await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, local.balanceA, local.claimableRewardForA, local.settledARps);
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK));
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.claimReward(userA.address);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await expect(txs[0]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userA.address, local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 2250, local.aRps.mul(local.balanceA).div(MASK).add(local.claimableRewardForA));
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, 300, 0, local.settledARps);
    local.claimRewardForA();
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.stake(userA.address, 300);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 1600, local.aRps.mul(local.balanceA).div(MASK));
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(0);
    await network.provider.send('evm_mine');
    await local.recordReward(0);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');
    await network.provider.send('evm_mine');

    txs[0] = await stakingContract.unstake(userA.address, 300);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 0, local.aRps.mul(local.balanceA).div(MASK));

    txs[0] = await stakingContract.unstake(userA.address, 100);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 0, local.aRps.mul(local.balanceA).div(MASK));
    await expectLocalCalculationRight();

    txs[1] = await stakingContract.claimReward(userB.address);
    tx = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expect(txs[1]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userB.address, local.claimableRewardForB);
    await expect(txs[1]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userB.address, 0, local.aRps.mul(local.balanceB).div(MASK));
    await expect(txs[1]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userB.address, local.balanceB, 0, local.settledARps);
    local.claimRewardForB();
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(tx!, [poolAddr], [local.aRps]);
    local.settledPools();
    await expectLocalCalculationRight();
  });

  it('Should be able to calculate right reward after claiming', async () => {
    const lastCredited = local.aRps.mul(300).div(MASK);

    txs[0] = await stakingContract.recordReward(1000);
    txs[1] = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(txs[0]!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(txs[1]!, [poolAddr], [local.aRps]);
    local.settledPools();
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.claimReward(userA.address);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await expect(txs[0]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userA.address, local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 0, lastCredited.add(local.claimableRewardForA));
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, 300, 0, local.aRps);
    local.claimRewardForA();
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.claimReward(userA.address);
    await network.provider.send('evm_mine');
    local.claimRewardForA();
    await expectLocalCalculationRight();
    await expect(txs[0]!).emit(stakingContract, 'RewardClaimed').withArgs(poolAddr, userA.address, 0);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 0, lastCredited.add(750));
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, 300, 0, local.settledARps);

    txs[1] = await stakingContract.claimReward(userB.address);
    tx = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expect(txs[1]!).emit(stakingContract, 'RewardClaimed').withArgs(poolAddr, userB.address, 250);
    await expect(txs[1]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userB.address, 0, 1750 + 250);
    await expect(txs[1]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userB.address, 100, 0, local.settledARps);
    local.claimRewardForB();
    local.settledPools();
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(tx!, [poolAddr], [local.settledARps]);
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions from multi-users occurring in the same block', async () => {
    txs[0] = await stakingContract.stake(userA.address, 100);
    await network.provider.send('evm_mine');
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, local.balanceA, local.claimableRewardForA, local.settledARps);
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, local.claimableRewardForA, local.aRps.mul(local.balanceA).div(MASK));

    txs[0] = await stakingContract.stake(userA.address, 300);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 750, local.aRps.mul(local.balanceA).div(MASK));
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[1] = await stakingContract.stake(userB.address, 200);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await expect(txs[1]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userB.address, local.balanceB, local.claimableRewardForB, local.settledARps);
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[1] = await stakingContract.unstake(userB.address, 200);
    txs[0] = await stakingContract.unstake(userA.address, 400);
    tx = await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.syncBalance();
    let lastCreditedB = local.aRps.mul(local.balanceB).div(MASK);
    let lastCreditedA = local.aRps.mul(local.balanceA).div(MASK);
    await expect(txs[1]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userB.address, local.accumulatedRewardForB, lastCreditedB);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 3725, lastCreditedA);
    await local.recordReward(1000);
    await expect(tx!).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(poolAddr, local.aRps);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.claimReward(userA.address);
    txs[1] = await stakingContract.claimReward(userB.address);
    await network.provider.send('evm_mine');
    lastCreditedA = lastCreditedA.add(local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userA.address, local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, local.balanceA, 0, local.settledARps);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 3725, lastCreditedA);
    lastCreditedB = lastCreditedB.add(local.claimableRewardForB);
    await expect(txs[1]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userB.address, local.claimableRewardForB);
    await expect(txs[1]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userB.address, local.balanceB, 0, local.settledARps);
    await expect(txs[1]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userB.address, 1275, lastCreditedB);
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.unstake(userA.address, 200);
    tx = await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.syncBalance();
    lastCreditedA = local.balanceA.mul(local.aRps).div(MASK);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, local.accumulatedRewardForA, lastCreditedA);
    local.settledPools();
    await StakingContract.expects.emitSettledPoolsUpdatedEvent(tx!, [poolAddr], [local.settledARps]);
    await expectLocalCalculationRight();

    txs[0] = await stakingContract.claimReward(userA.address);
    txs[1] = await stakingContract.claimReward(userB.address);
    await network.provider.send('evm_mine');
    lastCreditedA = lastCreditedA.add(local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userA.address, local.claimableRewardForA);
    await expect(txs[0]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userA.address, local.balanceA, 0, local.settledARps);
    await expect(txs[0]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userA.address, 3725, lastCreditedA);
    lastCreditedB = lastCreditedB.add(local.claimableRewardForB);
    await expect(txs[1]!)
      .emit(stakingContract, 'RewardClaimed')
      .withArgs(poolAddr, userB.address, local.claimableRewardForB);
    await expect(txs[1]!)
      .emit(stakingContract, 'SettledRewardUpdated')
      .withArgs(poolAddr, userB.address, local.balanceB, 0, local.settledARps);
    await expect(txs[1]!)
      .emit(stakingContract, 'PendingRewardUpdated')
      .withArgs(poolAddr, userB.address, 1275, lastCreditedB);
    local.claimRewardForA();
    local.claimRewardForB();
    await expectLocalCalculationRight();
  });

  it('Should work properly with staking actions occurring in the same block', async () => {
    await stakingContract.stake(userA.address, 100);
    await stakingContract.unstake(userA.address, 100);
    await stakingContract.stake(userA.address, 100);
    await stakingContract.stake(userB.address, 200);
    await stakingContract.unstake(userB.address, 200);
    await stakingContract.recordReward(1000);
    await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.settledPools();
    await expectLocalCalculationRight();

    await stakingContract.recordReward(1000);
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.slash();
    await network.provider.send('evm_mine');
    local.slash();
    await expectLocalCalculationRight();

    await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await expectLocalCalculationRight();

    await stakingContract.recordReward(1000);
    await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.settledPools();
    await expectLocalCalculationRight();

    await stakingContract.recordReward(1000);
    await stakingContract.settledPools([ethers.constants.AddressZero]);
    await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    local.settledPools();
    await expectLocalCalculationRight();

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
