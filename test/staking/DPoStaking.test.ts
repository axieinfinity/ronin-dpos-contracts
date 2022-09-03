import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import {
  DPoStaking,
  DPoStaking__factory,
  MockStaking__factory,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { MockValidatorSetForStaking__factory } from '../../src/types/factories/MockValidatorSetForStaking__factory';
import { MockValidatorSetForStaking } from '../../src/types/MockValidatorSetForStaking';

const EPS = 1;

let poolAddr: string = ethers.constants.AddressZero;
let otherPoolAddr: string = ethers.constants.AddressZero;
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
  console.log('expectLocalCalculationRight', poolAddr);

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

const minValidatorBalance = BigNumber.from(10).pow(18);

describe('DPoStaking test', () => {
  before(async () => {
    [deployer, proxyAdmin, userA, userB, ...validatorCandidates] = await ethers.getSigners();
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
    poolAddr = validatorCandidates[0].address;
    otherPoolAddr = validatorCandidates[1].address;
  });

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

  it('Should work properly with staking actions occurring sequentially for a normal period', async () => {
    console.log({ poolAddr, otherPoolAddr });
    console.log([userA.address, userB.address]);

    // TODO: subtract commission rate in contract
    console.log('0');

    await stakingContract.connect(userA).delegate(poolAddr, { value: 100 });
    console.log('1');
    await stakingContract.connect(userB).delegate(poolAddr, { value: 100 });
    console.log('2');
    await stakingContract.connect(userA).delegate(otherPoolAddr, { value: 100 });
    console.log('3');
    await network.provider.send('evm_mine');
    console.log('===========>a', [
      await stakingContract.balanceOf(poolAddr, userA.address),
      await stakingContract.totalBalance(poolAddr),
    ]);

    console.log(
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );

    await validatorContract.connect(validatorCandidates[0]).depositReward({ value: 1000 });
    await network.provider.send('evm_mine');
    await local.recordReward(1000);
    await expectLocalCalculationRight();
    console.log(
      0,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );

    await validatorContract.connect(validatorCandidates[1]).depositReward({ value: 1000 });
    await network.provider.send('evm_mine');
    console.log(
      1,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await network.provider.send('evm_mine');
    console.log(
      2,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await network.provider.send('evm_mine');
    console.log(
      3,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await local.recordReward(1000);
    await expectLocalCalculationRight();
    console.log(
      4,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );

    await stakingContract.connect(userA).delegate(poolAddr, { value: 100 });
    await network.provider.send('evm_mine');
    console.log(
      5,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await expectLocalCalculationRight();

    await validatorContract.connect(validatorCandidates[0]).depositReward({ value: 1000 });
    await network.provider.send('evm_mine');
    console.log(
      6,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    await stakingContract.connect(userA).undelegate(poolAddr, 200);
    await validatorContract.connect(validatorCandidates[0]).depositReward({ value: 1000 });
    await network.provider.send('evm_mine');
    console.log(
      7,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await local.recordReward(1000);
    await expectLocalCalculationRight();

    // await stakingContract.stake(userA.address, 200);
    await network.provider.send('evm_mine');
    console.log(
      8,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    await local.recordReward(0);
    await expectLocalCalculationRight();

    await validatorContract.settledReward([poolAddr, otherPoolAddr]);
    // await stakingContract.endPeriod();
    await network.provider.send('evm_mine');
    console.log(
      9,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
    console.log(local);

    local.commitRewardPool(); // ?? WHY: still right
    console.log(local);
    await expectLocalCalculationRight();

    await network.provider.send('evm_mine');
    console.log(
      9,
      await ethers.provider.getBlockNumber(),
      await validatorContract.periodOf(await ethers.provider.getBlockNumber())
    );
  });

  // it('Should work properly with staking actions occurring sequentially for a slashed period', async () => {
  //   await stakingContract.stake(userA.address, 100);
  //   await network.provider.send('evm_mine');
  //   await expectLocalCalculationRight();
  //   await local.recordReward(0);

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.stake(userA.address, 300);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.slash();
  //   await network.provider.send('evm_mine');
  //   local.slash();
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(0);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(0);
  //   await expectLocalCalculationRight();

  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');

  //   await stakingContract.unstake(userA.address, 300);
  //   await network.provider.send('evm_mine');
  //   await stakingContract.unstake(userA.address, 100);
  //   await network.provider.send('evm_mine');
  //   await expectLocalCalculationRight();

  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await expectLocalCalculationRight();
  // });

  // it('Should work properly with staking actions occurring sequentially for a slashed period again', async () => {
  //   await stakingContract.stake(userA.address, 100);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(0);
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.claimRewardForA();
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.stake(userA.address, 300);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.slash();
  //   await network.provider.send('evm_mine');
  //   local.slash();
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(0);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(0);
  //   await expectLocalCalculationRight();

  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');
  //   await network.provider.send('evm_mine');

  //   await stakingContract.unstake(userA.address, 300);
  //   await network.provider.send('evm_mine');
  //   await stakingContract.unstake(userA.address, 100);
  //   await network.provider.send('evm_mine');
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForB();
  //   await expectLocalCalculationRight();
  // });

  // it('Should be able to calculate right reward after claiming', async () => {
  //   await stakingContract.recordReward(1000);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.claimRewardForA();
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForA();
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForB();
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();
  // });

  // it('Should work properly with staking actions from multi-users occurring in the same block', async () => {
  //   await stakingContract.stake(userA.address, 100);
  //   await network.provider.send('evm_mine');

  //   await stakingContract.stake(userA.address, 300);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.stake(userB.address, 200);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.unstake(userB.address, 200);
  //   await stakingContract.unstake(userA.address, 400);
  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForA();
  //   local.claimRewardForB();
  //   await expectLocalCalculationRight();

  //   await stakingContract.unstake(userA.address, 200);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForA();
  //   local.claimRewardForB();
  //   await expectLocalCalculationRight();
  // });

  // it('Should work properly with staking actions occurring in the same block', async () => {
  //   await stakingContract.stake(userA.address, 100);
  //   await stakingContract.unstake(userA.address, 100);
  //   await stakingContract.stake(userA.address, 100);
  //   await stakingContract.unstake(userA.address, 100);
  //   await stakingContract.stake(userB.address, 200);
  //   await stakingContract.unstake(userB.address, 200);
  //   await stakingContract.stake(userB.address, 200);
  //   await stakingContract.unstake(userB.address, 200);
  //   await stakingContract.stake(userB.address, 200);
  //   await stakingContract.stake(userA.address, 100);
  //   await stakingContract.unstake(userA.address, 100);
  //   await stakingContract.unstake(userB.address, 200);
  //   await stakingContract.stake(userB.address, 200);
  //   await stakingContract.unstake(userA.address, 100);
  //   await stakingContract.stake(userA.address, 100);
  //   await stakingContract.unstake(userB.address, 200);
  //   await stakingContract.recordReward(1000);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   await expectLocalCalculationRight();

  //   await stakingContract.slash();
  //   await network.provider.send('evm_mine');
  //   local.slash();
  //   await expectLocalCalculationRight();

  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();

  //   await stakingContract.recordReward(1000);
  //   await stakingContract.commitRewardPool();
  //   await stakingContract.endPeriod();
  //   await network.provider.send('evm_mine');
  //   await local.recordReward(1000);
  //   local.commitRewardPool();
  //   await expectLocalCalculationRight();

  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userA.address);
  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.claimReward(userB.address);
  //   await stakingContract.claimReward(userB.address);
  //   await network.provider.send('evm_mine');
  //   local.claimRewardForA();
  //   local.claimRewardForB();
  //   await expectLocalCalculationRight();
  // });
});
