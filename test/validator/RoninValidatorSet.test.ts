import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  Staking,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  Staking__factory,
  MockSlashIndicatorExtended__factory,
  MockSlashIndicatorExtended,
  RoninGovernanceAdmin__factory,
  RoninGovernanceAdmin,
} from '../../src/types';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';

let roninValidatorSet: MockRoninValidatorSetExtended;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let treasury: SignerWithAddress;
let bridgeOperator: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];
let currentValidatorSet: string[];

const slashFelonyAmount = 100;
const maxValidatorNumber = 4;
const maxValidatorCandidate = 100;
const minValidatorBalance = BigNumber.from(20000);
const validatorBonusPerBlock = BigNumber.from(5000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);

describe('Ronin Validator Set test', () => {
  before(async () => {
    [coinbase, treasury, bridgeOperator, deployer, governor, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 5);
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const { slashContractAddress, validatorContractAddress, stakingContractAddress, roninGovernanceAdminAddress } =
      await initTest('RoninValidatorSet')({
        trustedOrganizations: [governor.address].map((addr) => ({ addr, weight: 100 })),
        minValidatorBalance,
        maxValidatorNumber,
        maxValidatorCandidate,
        slashFelonyAmount,
        validatorBonusPerBlock,
        bridgeOperatorBonusPerBlock,
      });

    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);
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
    await RoninValidatorSet.expects.emitWrappedUpEpochEvent(tx!);
    expect(await roninValidatorSet.getValidators()).eql([]);
  });

  it('Should be able to wrap up epoch and not sync the validator set', async () => {
    for (let i = 0; i <= 3; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          2_00,
          {
            value: minValidatorBalance.add(i),
          }
        );
    }

    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    await RoninValidatorSet.expects.emitWrappedUpEpochEvent(tx!);
    expect(await roninValidatorSet.getValidators()).eql([]);
    expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
  });

  it('Should be able to wrap up epoch and sync validator set from staking contract', async () => {
    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(
      tx!,
      validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.address)
    );

    expect(await roninValidatorSet.getValidators()).eql(
      validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.address)
    );
  });

  it(`Should be able to wrap up epoch and pick top ${maxValidatorNumber} to be validators`, async () => {
    await stakingContract
      .connect(coinbase)
      .applyValidatorCandidate(
        coinbase.address,
        coinbase.address,
        treasury.address,
        bridgeOperator.address,
        1_00 /* 1% */,
        {
          value: minValidatorBalance.mul(100),
        }
      );
    for (let i = 4; i < validatorCandidates.length; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          2_00,
          {
            value: minValidatorBalance.add(i),
          }
        );
    }
    expect((await roninValidatorSet.getValidatorCandidates()).length).eq(validatorCandidates.length + 1);

    let tx: ContractTransaction;
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
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
    expect(await roninValidatorSet.getValidators()).eql(currentValidatorSet);
  });

  it('Should not be able to submit block reward using unauthorized account', async () => {
    await expect(roninValidatorSet.submitBlockReward()).revertedWith(
      'RoninValidatorSet: method caller must be coinbase'
    );
  });

  it('Should be able to submit block reward using coinbase account', async () => {
    const tx = await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await RoninValidatorSet.expects.emitBlockRewardSubmittedEvent(tx, coinbase.address, 100, validatorBonusPerBlock);
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
    await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(tx!, 5049); // (5000 + 100) * 99%
    await RoninValidatorSet.expects.emitMiningRewardDistributedEvent(tx!, coinbase.address, treasury.address, 51); // (5000 + 100) * 1%
    await RoninValidatorSet.expects.emitBridgeOperatorRewardDistributedEvent(
      tx!,
      coinbase.address,
      treasury.address,
      37
    );
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(88); // = (5000 + 100) * 1% + 37 = (51 + 37)
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(
      5049 // (5000 + 100) * 99% = 99% of the reward, since the pool is only staked by the coinbase
    );
  });

  it('Should not allocate minting fee for the slashed validators, but allocate bridge reward', async () => {
    let tx: ContractTransaction;
    {
      const balance = await treasury.getBalance();
      await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
      tx = await slashIndicator.slashMisdemeanor(coinbase.address);
      expect(tx).emit(roninValidatorSet, 'ValidatorPunished').withArgs(coinbase.address, 0, 0);

      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const balanceDiff = (await treasury.getBalance()).sub(balance);
      expect(balanceDiff).eq(0);
      // The delegators don't receives the new rewards until the period is ended
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(
        5049 // (5000 + 100) * 99% = 99% of the reward, since the pool is only staked by the coinbase
      );
      await RoninValidatorSet.expects.emitWrappedUpEpochEvent(tx!);
      expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
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
      expect(balanceDiff).eq(bridgeOperatorBonusPerBlock); // bridge bonus
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(
        5049 // (5000 + 100) * 99% = 99% of the reward, since the pool is only staked by the coinbase
      );
      await RoninValidatorSet.expects.emitWrappedUpEpochEvent(tx!);
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    }
  });

  it('Should be able to record delegating reward for a successful period', async () => {
    let tx: ContractTransaction;
    const balance = await treasury.getBalance();
    await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    await RoninValidatorSet.expects.emitWrappedUpEpochEvent(tx!);
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
    await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(
      tx!,
      validatorBonusPerBlock.add(100).div(100).mul(99)
    );

    const balanceDiff = (await treasury.getBalance()).sub(balance);
    const expectingBalanceDiff = validatorBonusPerBlock.add(100).div(100).add(bridgeOperatorBonusPerBlock);
    expect(balanceDiff).eq(expectingBalanceDiff);
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(
      validatorBonusPerBlock.add(100).div(100).mul(99).mul(2)
    );
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
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(
      validatorBonusPerBlock.add(100).div(100).mul(99).mul(2)
    );
    await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, currentValidatorSet);
  });
});
