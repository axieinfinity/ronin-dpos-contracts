import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { DPoStaking, DPoStaking__factory, TransparentUpgradeableProxy__factory } from '../../src/types';
import { MockValidatorSetForStaking__factory } from '../../src/types/factories/MockValidatorSetForStaking__factory';
import { MockValidatorSetForStaking } from '../../src/types/MockValidatorSetForStaking';

const EPS = 1;

let poolAddr: SignerWithAddress;
let otherPoolAddr: SignerWithAddress;
let deployer: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let validatorContract: MockValidatorSetForStaking;
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

const minValidatorBalance = BigNumber.from(0);

describe('DPoStaking test', () => {
  before(async () => {
    [deployer, proxyAdmin, userA, userB, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 2);
    const nonce = await deployer.getTransactionCount();
    const proxyContractAddress = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    validatorContract = await new MockValidatorSetForStaking__factory(deployer).deploy(proxyContractAddress, 10, 2);
    const logicContract = await new DPoStaking__factory(deployer).deploy();
    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        28800,
        validatorContract.address,
        ethers.constants.AddressZero,
        50,
        minValidatorBalance,
      ])
    );
    stakingContract = DPoStaking__factory.connect(proxyContract.address, deployer);
    expect(proxyContractAddress.toLowerCase()).eq(proxyContract.address.toLowerCase());
    poolAddr = validatorCandidates[0];
    otherPoolAddr = validatorCandidates[1];
  });

  describe('Validator candidate test', () => {
    it('Should not be able to propose validator with insufficient amount', async () => {
      await expect(stakingContract.proposeValidator(userA.address, userA.address, 1)).revertedWith(
        'StakingManager: insufficient amount'
      );
    });

    it('Should be able to propose validator with sufficient amount', async () => {
      for (let i = 0; i < validatorCandidates.length; i++) {
        const candidate = validatorCandidates[i];
        await stakingContract.connect(candidate).proposeValidator(
          candidate.address,
          candidate.address,
          1, // 0.01%
          { value: minValidatorBalance }
        );
      }
      await network.provider.send('evm_setAutomine', [false]);
    });

    it('Should not be able to call stake/unstake when the method is not the candidate owner', async () => {});

    it('Should be able to stake/unstake as a validator', async () => {});

    it('Should be not able to unstake with the balance left is not larger than the minimum balance threshold', async () => {});
  });

  describe('Delegator test', () => {
    // TODO
  });

  describe('Reward Calculation test', () => {
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
      console.log(local);

      await stakingContract.connect(userA).undelegate(poolAddr.address, 200);
      await validatorContract.connect(poolAddr).depositReward({ value: 1000 });
      await network.provider.send('evm_mine');
      await local.recordReward(1000);
      console.log(local);
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
