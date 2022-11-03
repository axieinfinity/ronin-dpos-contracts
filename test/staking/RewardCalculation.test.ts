import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';

import { MockStaking, MockStaking__factory } from '../../src/types';

const MASK = BigNumber.from(10).pow(18);
const poolAddr = ethers.constants.AddressZero;

let period = 1;
let deployer: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let stakingContract: MockStaking;
let aRps: BigNumber;

describe('Reward Calculation test', () => {
  let tx: ContractTransaction;
  const txs: ContractTransaction[] = [];

  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
  });

  describe('Period: 0 -> 1', () => {
    it('Should be able to stake/unstake at the very first period', async () => {
      txs[0] = await stakingContract.stake(userA.address, 500);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
      txs[0] = await stakingContract.unstake(userA.address, 450);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
      txs[0] = await stakingContract.stake(userA.address, 50);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
    });

    it('Should be able to record reward for the pool', async () => {
      await stakingContract.increaseReward(1000);
      await stakingContract.decreaseReward(500);
      aRps = MASK.mul(500 / 100);
      tx = await stakingContract.endPeriod(); // period = 1
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(500);
    });
  });

  describe('Period: 1 -> 2', () => {
    it('Should not be able to record reward with invalid arguments', async () => {
      tx = await stakingContract.recordRewards([poolAddr], [100, 100]);
      await expect(tx).emit(stakingContract, 'PoolsUpdateFailed').withArgs(period, [poolAddr], [100, 100]);
    });

    it('Should not be able to record reward more than once for a pool', async () => {
      aRps = aRps.add(MASK.mul(1000 / 100));
      tx = await stakingContract.recordRewards([poolAddr], [1000]);
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);
      tx = await stakingContract.recordRewards([poolAddr], [1000]);
      await expect(tx).emit(stakingContract, 'PoolUpdateConflicted').withArgs(period, poolAddr);
      await stakingContract.increasePeriod(); // period = 2
      period++;
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(1500); // 1000 + 500 from the last period
    });
  });

  describe('Period: 2 -> 3', () => {
    it('Should be able to change the staking amount and the reward moved into the debited part', async () => {
      txs[0] = await stakingContract.stake(userA.address, 200);
      await expect(txs[0]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userA.address, 1500);
      txs[0] = await stakingContract.unstake(userA.address, 100);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
    });

    it('Should be able to claim the earned reward', async () => {
      txs[0] = await stakingContract.claimReward(userA.address);
      await expect(txs[0]).emit(stakingContract, 'RewardClaimed').withArgs(poolAddr, userA.address, 1500);
      await expect(txs[0]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userA.address, 0);
    });

    it('Should be able to change the staking amount and the debited part is empty', async () => {
      txs[0] = await stakingContract.stake(userA.address, 200);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
      txs[0] = await stakingContract.unstake(userA.address, 350);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
      expect(await stakingContract.stakingAmountOf(poolAddr, userA.address)).eq(50);
      txs[0] = await stakingContract.stake(userA.address, 250);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');

      txs[1] = await stakingContract.stake(userB.address, 200);
      await expect(txs[1]).not.emit(stakingContract, 'UserRewardUpdated');
      expect(await stakingContract.stakingAmountOf(poolAddr, userB.address)).eq(200);
    });

    it('Should be able to distribute reward based on the smallest amount in the last period', async () => {
      aRps = aRps.add(MASK.mul(1000 / 50));
      await stakingContract.increaseReward(1000);
      tx = await stakingContract.endPeriod(); // period = 3
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(1000);
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);
    });
  });

  describe('Period: 3 -> 10', () => {
    it('Should be able to get right reward', async () => {
      aRps = aRps.add(MASK.mul(1000 / 500));
      await stakingContract.increaseReward(1000);
      tx = await stakingContract.endPeriod(); // period 4
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);

      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(1600); // 3/5 of 1000 + 1000 from the last period
      expect(await stakingContract.getReward(poolAddr, userB.address)).eq(400); // 2/5 of 1000
    });

    it('Should be able to unstake and receives reward based on the smallest amount in the last period', async () => {
      txs[0] = await stakingContract.unstake(userA.address, 250);
      await expect(txs[0]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userA.address, 1600);
      expect(await stakingContract.stakingAmountOf(poolAddr, userA.address)).eq(50);

      txs[1] = await stakingContract.unstake(userB.address, 150);
      await expect(txs[1]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userB.address, 400);
      expect(await stakingContract.stakingAmountOf(poolAddr, userB.address)).eq(50);

      aRps = aRps.add(MASK.mul(1000 / 100));
      await stakingContract.increaseReward(1000);
      tx = await stakingContract.endPeriod(); // period 5
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(2100); // 50% of 1000 + 1600 from the last period
      expect(await stakingContract.getReward(poolAddr, userB.address)).eq(900); // 50% of 1000 + 400 from the last period
    });

    it('Should not distribute reward for ones who unstake all in the period', async () => {
      txs[1] = await stakingContract.unstake(userB.address, 50);
      await expect(txs[1]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userB.address, 900);
      expect(await stakingContract.stakingAmountOf(poolAddr, userB.address)).eq(0);

      aRps = aRps.add(MASK.mul(1000 / 50));
      await stakingContract.increaseReward(1000);
      tx = await stakingContract.endPeriod(); // period 6
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [await stakingContract.stakingTotal(poolAddr)]);
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(3100); // 1000 + 2100 from the last period
    });

    it('The pool should be fine when no one stakes', async () => {
      txs[0] = await stakingContract.unstake(userA.address, 50);
      await expect(txs[0]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userA.address, 3100);
      expect(await stakingContract.stakingAmountOf(poolAddr, userA.address)).eq(0);
      expect(await stakingContract.stakingAmountOf(poolAddr, userB.address)).eq(0);

      aRps = aRps.add(0);
      await stakingContract.increaseReward(1000);
      tx = await stakingContract.endPeriod(); // period 7
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [0]);
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(3100);
      expect(await stakingContract.getReward(poolAddr, userB.address)).eq(900);
    });

    it('The rewards should be still when the pool has no reward for multi periods', async () => {
      tx = await stakingContract.endPeriod(); // period 8
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [0]);
      tx = await stakingContract.endPeriod(); // period 9
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [0]);
      tx = await stakingContract.endPeriod(); // period 10
      await expect(tx)
        .emit(stakingContract, 'PoolsUpdated')
        .withArgs(period++, [poolAddr], [aRps], [0]);
      expect(await stakingContract.getReward(poolAddr, userA.address)).eq(3100);
      expect(await stakingContract.getReward(poolAddr, userB.address)).eq(900);
    });

    it('Should be able to claim reward after all', async () => {
      txs[0] = await stakingContract.unstake(userA.address, 0);
      await expect(txs[0]).not.emit(stakingContract, 'UserRewardUpdated');
      txs[0] = await stakingContract.claimReward(userA.address);
      await expect(txs[0]).emit(stakingContract, 'RewardClaimed').withArgs(poolAddr, userA.address, 3100);
      await expect(txs[0]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userA.address, 0);

      txs[1] = await stakingContract.claimReward(userB.address);
      await expect(txs[1]).emit(stakingContract, 'RewardClaimed').withArgs(poolAddr, userB.address, 900);
      await expect(txs[1]).emit(stakingContract, 'UserRewardUpdated').withArgs(poolAddr, userB.address, 0);
      txs[1] = await stakingContract.unstake(userA.address, 0);
      await expect(txs[1]).not.emit(stakingContract, 'UserRewardUpdated');
    });
  });
});
