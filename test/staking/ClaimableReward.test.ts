import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
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

describe('Claimable Reward test', () => {
  before(async () => {
    [deployer, userA, userB] = await ethers.getSigners();
    stakingContract = await new MockStaking__factory(deployer).deploy(poolAddr);
  });

  it('Should calculate correctly the claimable reward in the normal case', async () => {
    await setupNormalCase(stakingContract);
    expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
    expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
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
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.recordReward(1000);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250 + 250);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250 + 250);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250 + 250);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250 + 250);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 750 + 750);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 250 + 250);
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
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.unstake(userA.address, 800);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
      });

      it('Should the claimable reward increase when the pool is settled', async () => {
        await stakingContract.recordReward(1000);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100 + 100);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100 + 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100 + 100);
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
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward not change when the pool is slashed', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward increase when the pool records reward', async () => {
        await stakingContract.recordReward(1000);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
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
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward not change when the pool is slashed', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500);
      });

      it('Should the claimable reward increase when the pool records reward', async () => {
        await stakingContract.recordReward(1000);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
      });

      it('Should the claimable reward be still, no matter whether the pool is slashed or settled', async () => {
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.settledPools([poolAddr]);
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
        await stakingContract.slash();
        await stakingContract.endPeriod();
        expect(await stakingContract.getClaimableReward(poolAddr, userA.address)).eq(500 + 900);
        expect(await stakingContract.getClaimableReward(poolAddr, userB.address)).eq(500 + 100);
      });
    });
  });
});
