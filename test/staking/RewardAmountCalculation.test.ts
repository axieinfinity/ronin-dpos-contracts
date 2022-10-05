import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { MockStaking, MockStaking__factory } from '../../src/types';

const poolAddr = ethers.constants.AddressZero;

let deployer: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let stakingContract: MockStaking;

const setupNormalCase = async (stakingContract: MockStaking) => {
  await stakingContract.stake(userA.address, 100);
  await stakingContract.stake(userB.address, 100);
  await stakingContract.recordReward(1000);
  await stakingContract.settledPools([poolAddr]);
  await stakingContract.endPeriod();
};

const expectPendingRewards = async (expectingA: number, expectingB: number) => {
  expect(await stakingContract.getPendingReward(poolAddr, userA.address)).eq(expectingA);
  expect(await stakingContract.getPendingReward(poolAddr, userB.address)).eq(expectingB);
};

const expectClaimableRewards = async (expectingA: number, expectingB: number) => {
  expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(expectingA);
  expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(expectingB);
};

describe('Claimable/Pending Reward Calculation test', () => {
  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
  });

  it('Should calculate correctly the claimable reward in the normal case', async () => {
    await setupNormalCase(stakingContract);
    await expectClaimableRewards(500, 500);
    await expectPendingRewards(0, 0);
  });

  describe('Interaction with a pool that will be settled', async () => {
    describe('One interaction per period', async () => {
      before(async () => {
        stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
        await setupNormalCase(stakingContract);
      });

      it('Should the claimable reward not change when the user interacts in the pending period', async () => {
        await stakingContract.stake(userA.address, 200);
        await stakingContract.recordReward(1000);
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(750, 250);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750, 500 + 250);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750, 500 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750, 500 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750, 500 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750, 500 + 250);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.recordReward(1000);
        await expectPendingRewards(750, 250);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750 + 750, 500 + 250 + 250);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750 + 750, 500 + 250 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750 + 750, 500 + 250 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750 + 750, 500 + 250 + 250);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 750 + 750, 500 + 250 + 250);
        await expectPendingRewards(0, 0);
      });
    });

    describe('Many interactions per period', async () => {
      before(async () => {
        stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
        await setupNormalCase(stakingContract);
      });

      it('Should the claimable reward not change when the user interacts in the pending period', async () => {
        await stakingContract.stake(userA.address, 200);
        await stakingContract.stake(userA.address, 500);
        await stakingContract.stake(userA.address, 100);
        await stakingContract.recordReward(1000);
        await stakingContract.stake(userA.address, 800);
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(900, 100);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.unstake(userA.address, 800);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.recordReward(1000);
        await expectPendingRewards(900, 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900 + 900, 500 + 100 + 100);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900 + 900, 500 + 100 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900 + 900, 500 + 100 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900 + 900, 500 + 100 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900 + 900, 500 + 100 + 100);
        await expectPendingRewards(0, 0);
      });
    });
  });

  describe('Interaction with a pool that will be slashed', async () => {
    describe('One interaction per period', async () => {
      before(async () => {
        stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
        await setupNormalCase(stakingContract);
      });

      it('Should the claimable reward not change when the user interacts in the pending period', async () => {
        await stakingContract.stake(userA.address, 200);
        await stakingContract.recordReward(1000);
        await stakingContract.stake(userA.address, 600);
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(750, 250);
      });

      it('Should the claimable reward not change when the pool is slashed', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward increase when the pool records reward', async () => {
        await stakingContract.recordReward(1000);
        await expectPendingRewards(900, 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
      });
    });

    describe('Many interactions per period', async () => {
      before(async () => {
        stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
        await setupNormalCase(stakingContract);
      });

      it('Should the claimable reward not change when the user interacts in the pending period', async () => {
        await stakingContract.stake(userA.address, 200);
        await stakingContract.unstake(userA.address, 150);
        await stakingContract.unstake(userA.address, 50);
        await stakingContract.recordReward(1000);
        await stakingContract.stake(userA.address, 500);
        await stakingContract.stake(userA.address, 300);
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(500, 500);
      });

      it('Should the claimable reward not change when the pool is slashed', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500, 500);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward increase when the pool records reward', async () => {
        await stakingContract.recordReward(1000);
        await expectPendingRewards(900, 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        await expectClaimableRewards(500 + 900, 500 + 100);
        await expectPendingRewards(0, 0);
      });
    });
  });
});
