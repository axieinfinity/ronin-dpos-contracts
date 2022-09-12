import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  Staking,
  MockRoninValidatorSetEpochSetter,
  MockRoninValidatorSetEpochSetter__factory,
  Staking__factory,
  TransparentUpgradeableProxy__factory,
  MockSlashIndicator,
  MockSlashIndicator__factory,
} from '../../src/types';
import * as RoninValidatorSet from '../../src/script/ronin-validator-set';
import { StakingVesting__factory } from '../../src/types/factories/StakingVesting__factory';

let roninValidatorSet: MockRoninValidatorSetEpochSetter;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicator;

let coinbase: SignerWithAddress;
let treasury: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

let currentValidatorSet: string[];

const slashFelonyAmount = 100;
const slashDoubleSignAmount = 1000;
const maxValidatorNumber = 4;
const minValidatorBalance = BigNumber.from(2);

const mineBatchTxs = async (fn: () => Promise<void>) => {
  await network.provider.send('evm_setAutomine', [false]);
  await fn();
  await network.provider.send('evm_mine');
  await network.provider.send('evm_setAutomine', [true]);
};

describe('Ronin Validator Set test', () => {
  before(async () => {
    [coinbase, treasury, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 5);
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const nonce = await deployer.getTransactionCount();
    const roninValidatorSetAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 3 });
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 5 });

    const stakingVestingLogic = await new StakingVesting__factory(deployer).deploy();
    const stakingVesting = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      stakingVestingLogic.address,
      proxyAdmin.address,
      stakingVestingLogic.interface.encodeFunctionData('initialize', [0, roninValidatorSetAddr])
    );

    slashIndicator = await new MockSlashIndicator__factory(deployer).deploy(
      roninValidatorSetAddr,
      slashFelonyAmount,
      slashDoubleSignAmount
    );
    await slashIndicator.deployed();

    roninValidatorSet = await new MockRoninValidatorSetEpochSetter__factory(deployer).deploy(
      governanceAdmin.address,
      slashIndicator.address,
      stakingContractAddr,
      stakingVesting.address,
      maxValidatorNumber
    );
    await roninValidatorSet.deployed();

    const logicContract = await new Staking__factory(deployer).deploy();
    await logicContract.deployed();

    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        roninValidatorSet.address,
        governanceAdmin.address,
        100,
        minValidatorBalance,
      ])
    );
    await proxyContract.deployed();
    stakingContract = Staking__factory.connect(proxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase()).eq(roninValidatorSet.address.toLowerCase());
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  it('Should not be able to wrap up epoch using unauthorized account', async () => {
    await expect(roninValidatorSet.connect(deployer).wrapUpEpoch()).revertedWith(
      'RoninValidatorSet: method caller must be coinbase'
    );
  });

  it('Should not be able to wrap up epoch when the epoch is not ending', async () => {
    await expect(roninValidatorSet.connect(coinbase).wrapUpEpoch()).revertedWith(
      'RoninValidatorSet: only allowed at the end of epoch'
    );
  });

  it('Should be able to wrap up epoch when the epoch is ending', async () => {
    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, []);
    expect(await roninValidatorSet.getValidators()).have.same.members([]);
  });

  it('Should be able to wrap up epoch and sync validator set from staking contract', async () => {
    for (let i = 0; i <= 3; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .proposeValidator(validatorCandidates[i].address, validatorCandidates[i].address, 2_00, {
          value: minValidatorBalance.add(i),
        });
    }

    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(
      tx!,
      validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.address)
    );

    expect(await roninValidatorSet.getValidators()).have.same.members(
      validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.address)
    );
  });

  it(`Should be able to wrap up epoch and pick top ${maxValidatorNumber} to be validators`, async () => {
    await stakingContract
      .connect(coinbase)
      .proposeValidator(coinbase.address, treasury.address, 1_00 /* 1% */, { value: 100 });
    for (let i = 4; i < validatorCandidates.length; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .proposeValidator(validatorCandidates[i].address, validatorCandidates[i].address, 2_00, {
          value: minValidatorBalance.add(i),
        });
    }
    expect((await stakingContract.getValidatorCandidates()).length).eq(validatorCandidates.length + 1);

    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      currentValidatorSet = [
        coinbase.address,
        ...validatorCandidates
          .slice(2)
          .reverse()
          .map((_) => _.address),
      ];
    });
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    expect(await roninValidatorSet.getValidators()).have.same.members(currentValidatorSet);
  });

  it('Should not be able to submit block reward using unauthorized account', async () => {
    await expect(roninValidatorSet.submitBlockReward()).revertedWith(
      'RoninValidatorSet: method caller must be coinbase'
    );
  });

  it('Should be able to submit block reward using coinbase account', async () => {
    const tx = await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await RoninValidatorSet.expects.emitBlockRewardSubmittedEvent(tx, coinbase.address, 100);
  });

  it('Should be able to get right reward at the end of period', async () => {
    const balance = await treasury.getBalance();
    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(tx!, 99);
    await RoninValidatorSet.expects.emitMiningRewardDistributedEvent(tx!, coinbase.address, 1);
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(1); // 100 * 1%
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99); // remain amount (99%)
  });

  it('Should not allocate minting fee for the slashed validators', async () => {
    let tx: ContractTransaction;
    {
      const balance = await treasury.getBalance();
      await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
      tx = await slashIndicator.slashMisdemeanor(coinbase.address);
      await RoninValidatorSet.expects.emitValidatorSlashedEvent(tx!, coinbase.address, 0, 0);

      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const balanceDiff = (await treasury.getBalance()).sub(balance);
      expect(balanceDiff).eq(0);
      // The delegators don't receives the new rewards until the period is ended
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99);
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    }

    {
      const balance = await treasury.getBalance();
      await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        await roninValidatorSet.endPeriod();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const balanceDiff = (await treasury.getBalance()).sub(balance);
      expect(balanceDiff).eq(0);
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99);
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    }
  });

  it('Should be able to record delegating reward for a successful epoch', async () => {
    let tx: ContractTransaction;
    const balance = await treasury.getBalance();
    await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(0);
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99 * 2);
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(tx!, 99);
  });

  it('Should not allocate reward for the slashed validator', async () => {
    let tx: ContractTransaction;
    const balance = await treasury.getBalance();
    await slashIndicator.slashMisdemeanor(coinbase.address);
    tx = await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await RoninValidatorSet.expects.emitRewardDeprecatedEvent(tx!, coinbase.address, 100);
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(0);
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99 * 2);
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
  });
});
