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
  StakingVesting__factory,
  StakingVesting,
} from '../../src/types';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';
import { expects as StakingVestingExpects } from '../helpers/staking-vesting';
import { mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import { BlockRewardDeprecatedType } from '../../src/script/ronin-validator-set';
import { Address } from 'hardhat-deploy/dist/types';
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';
import { SlashType } from '../../src/script/slash-indicator';

let roninValidatorSet: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let poolAdmin: SignerWithAddress;
let candidateAdmin: SignerWithAddress;
let consensusAddr: SignerWithAddress;
let treasury: SignerWithAddress;
let bridgeOperator: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

let currentValidatorSet: string[];
let lastPeriod: BigNumber;
let epoch: BigNumber;

const localValidatorCandidatesLength = 5;

const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 4;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const blockProducerBonusPerBlock = BigNumber.from(5000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);
const zeroTopUpAmount = 0;
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);

describe('Ronin Validator Set test', () => {
  before(async () => {
    [poolAdmin, candidateAdmin, consensusAddr, treasury, bridgeOperator, deployer, ...signers] =
      await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, localValidatorCandidatesLength * 5));

    await network.provider.send('hardhat_setCoinbase', [consensusAddr.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
    } = await initTest('RoninValidatorSet')({
      slashIndicatorArguments: {
        doubleSignSlashing: {
          slashDoubleSignAmount,
        },
        unavailabilitySlashing: {
          slashAmountForUnavailabilityTier2Threshold,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      stakingVestingArguments: {
        blockProducerBonusPerBlock,
        bridgeOperatorBonusPerBlock,
        topupAmount: zeroTopUpAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxValidatorCandidate,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
    });

    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, ...trustedOrgs.map((_) => _.governor));

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

  describe('Wrapping up epoch sanity check', async () => {
    it('Should not be able to wrap up epoch using unauthorized account', async () => {
      await expect(roninValidatorSet.connect(deployer).wrapUpEpoch()).revertedWith(
        'RoninValidatorSet: method caller must be coinbase'
      );
    });

    it('Should not be able to wrap up epoch when the epoch is not ending', async () => {
      await expect(roninValidatorSet.connect(consensusAddr).wrapUpEpoch()).revertedWith(
        'RoninValidatorSet: only allowed at the end of epoch'
      );
    });

    it('Should be able to wrap up epoch when the epoch is ending', async () => {
      let tx: ContractTransaction;
      epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });
      expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitBlockProducerSetUpdatedEvent(tx!, lastPeriod, []);
      expect(await roninValidatorSet.getValidators()).eql([]);
    });
  });

  describe('Wrapping up at the end of the epoch', async () => {
    it('Should be able to wrap up epoch at end of epoch and not sync the validator set', async () => {
      for (let i = 0; i <= 3; i++) {
        await stakingContract
          .connect(validatorCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            validatorCandidates[i].candidateAdmin.address,
            validatorCandidates[i].consensusAddr.address,
            validatorCandidates[i].treasuryAddr.address,
            validatorCandidates[i].bridgeOperator.address,
            2_00,
            {
              value: minValidatorStakingAmount.add(i),
            }
          );
      }

      let tx: ContractTransaction;
      epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });
      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, false);
      expect(await roninValidatorSet.getValidators()).eql([]);
      expect(await roninValidatorSet.getBlockProducers()).eql([]);
      await expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
    });
  });

  describe('Grant validator candidate sanity check', async () => {
    it('Should not be able to apply for candidate role with existed candidate admin address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[4].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[0].candidateAdmin.address,
          validatorCandidates[4].consensusAddr.address,
          validatorCandidates[4].treasuryAddr.address,
          validatorCandidates[4].bridgeOperator.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWith(
        `CandidateManager: candidate admin address ${validatorCandidates[0].candidateAdmin.address.toLocaleLowerCase()} is already exist`
      );
    });

    it('Should not be able to apply for candidate role with existed treasury address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[4].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[4].candidateAdmin.address,
          validatorCandidates[4].consensusAddr.address,
          validatorCandidates[0].treasuryAddr.address,
          validatorCandidates[4].bridgeOperator.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWith(
        `CandidateManager: treasury address ${validatorCandidates[0].treasuryAddr.address.toLocaleLowerCase()} is already exist`
      );
    });

    it('Should not be able to apply for candidate role with existed bridge operator address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[4].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[4].candidateAdmin.address,
          validatorCandidates[4].consensusAddr.address,
          validatorCandidates[4].treasuryAddr.address,
          validatorCandidates[0].bridgeOperator.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWith(
        `CandidateManager: bridge operator address ${validatorCandidates[0].bridgeOperator.address.toLocaleLowerCase()} is already exist`
      );
    });
  });

  describe('Wrapping up at the end of the period', async () => {
    let expectingValidatorsAddr: Address[];
    it('Should be able to wrap up epoch at end of period and sync validator set from staking contract', async () => {
      let tx: ContractTransaction;
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      expectingValidatorsAddr = validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.consensusAddr.address);

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, expectingValidatorsAddr);
      expect(await roninValidatorSet.getValidators()).eql(expectingValidatorsAddr);
      expect(await roninValidatorSet.getBlockProducers()).eql(expectingValidatorsAddr);
    });

    it('Should isValidator method returns `true` for validator', async () => {
      for (let validatorAddr of expectingValidatorsAddr) {
        expect(await roninValidatorSet.isValidator(validatorAddr)).eq(true);
      }
    });

    it('Should isValidator method returns `false` for non-validator', async () => {
      expect(await roninValidatorSet.isValidator(deployer.address)).eq(false);
    });

    it(`Should be able to wrap up epoch at the end of period and pick top ${maxValidatorNumber} to be validators`, async () => {
      await stakingContract
        .connect(poolAdmin)
        .applyValidatorCandidate(
          candidateAdmin.address,
          consensusAddr.address,
          treasury.address,
          bridgeOperator.address,
          1_00 /* 1% */,
          {
            value: minValidatorStakingAmount.mul(100),
          }
        );
      for (let i = 4; i < localValidatorCandidatesLength; i++) {
        await stakingContract
          .connect(validatorCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            validatorCandidates[i].candidateAdmin.address,
            validatorCandidates[i].consensusAddr.address,
            validatorCandidates[i].treasuryAddr.address,
            validatorCandidates[i].bridgeOperator.address,
            2_00,
            {
              value: minValidatorStakingAmount.add(i),
            }
          );
      }
      expect((await roninValidatorSet.getValidatorCandidates()).length).eq(localValidatorCandidatesLength + 1);

      let tx: ContractTransaction;
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        currentValidatorSet = [
          consensusAddr.address,
          ...validatorCandidates
            .slice(2)
            .reverse()
            .map((_) => _.consensusAddr.address),
        ];
      });
      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
      expect(await roninValidatorSet.getValidators()).eql(currentValidatorSet);
      expect(await roninValidatorSet.getBlockProducers()).eql(currentValidatorSet);
    });
  });

  describe('Recording and distributing rewards', async () => {
    describe('Sanity check', async () => {
      it('Should not be able to submit block reward using unauthorized account', async () => {
        await expect(roninValidatorSet.submitBlockReward()).revertedWith(
          'RoninValidatorSet: method caller must be coinbase'
        );
      });
    });

    describe('Submit block reward when staking vesting is insufficient', async () => {
      it('Should be able to submit block reward using coinbase account and not receive bonuses', async () => {
        const tx = await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });

        epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSet.expects.emitBlockRewardSubmittedEvent(tx, consensusAddr.address, 100, 0);

        await expect(tx).not.emit(stakingVesting, 'BonusTransferred');
        await StakingVestingExpects.emitBonusTransferFailedEvent(
          tx,
          undefined,
          roninValidatorSet.address,
          blockProducerBonusPerBlock,
          bridgeOperatorBonusPerBlock,
          BigNumber.from(0)
        );
      });
    });

    describe('Submit block reward when staking vesting is topped up', async () => {
      before(async () => {
        await expect(() => stakingVesting.receiveRON({ value: topUpAmount })).changeEtherBalance(
          stakingVesting.address,
          topUpAmount
        );
      });

      it('Should be able to submit block reward using coinbase account and receive bonuses', async () => {
        const tx = await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });

        await RoninValidatorSet.expects.emitBlockRewardSubmittedEvent(
          tx,
          consensusAddr.address,
          100,
          blockProducerBonusPerBlock
        );

        await expect(tx).not.emit(stakingVesting, 'BonusTransferFailed');
        await StakingVestingExpects.emitBonusTransferredEvent(
          tx,
          undefined,
          roninValidatorSet.address,
          blockProducerBonusPerBlock,
          bridgeOperatorBonusPerBlock
        );
      });

      it('Should be able to get right reward at the end of period', async () => {
        const balance = await treasury.getBalance();
        let tx: ContractTransaction;
        await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();

        lastPeriod = await roninValidatorSet.currentPeriod();
        epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
        await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(tx!, 5148); // (5000 + 100 + 100) * 99%
        await RoninValidatorSet.expects.emitMiningRewardDistributedEvent(
          tx!,
          consensusAddr.address,
          treasury.address,
          52
        ); // (5000 + 100 + 100) * 1%
        await expect(tx!)
          .emit(roninValidatorSet, 'BridgeOperatorRewardDistributed')
          .withArgs(
            consensusAddr.address,
            bridgeOperator.address,
            treasury.address,
            BigNumber.from(37).div(await roninValidatorSet.totalBridgeOperators())
          );
        const balanceDiff = (await treasury.getBalance()).sub(balance);
        expect(balanceDiff).eq(61); // = (5000 + 100 + 100) * 1% + 9 = (52 + 9)
        expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
          5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
        );
      });

      it('Should not allocate minting fee for the slashed validators, but allocate bridge reward', async () => {
        let tx: ContractTransaction;
        {
          const balance = await treasury.getBalance();
          await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
          tx = await slashIndicator.slashMisdemeanor(consensusAddr.address);
          await expect(tx)
            .emit(roninValidatorSet, 'ValidatorPunished')
            .withArgs(consensusAddr.address, lastPeriod, 0, 0, true, false);

          expect(await roninValidatorSet.totalDeprecatedReward()).equal(5100); // = 0 + (5000 + 100)

          epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
          lastPeriod = await roninValidatorSet.currentPeriod();
          await mineBatchTxs(async () => {
            await roninValidatorSet.endEpoch();
            tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
          });
          const balanceDiff = (await treasury.getBalance()).sub(balance);
          expect(balanceDiff).eq(0); // The delegators don't receives the new rewards until the period is ended
          expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
            5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
          );
          await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, false);
          await expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
        }

        {
          const balance = await treasury.getBalance();
          await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
          await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();

          epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
          lastPeriod = await roninValidatorSet.currentPeriod();
          await mineBatchTxs(async () => {
            await roninValidatorSet.endEpoch();
            tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
          });

          const balanceDiff = (await treasury.getBalance()).sub(balance);
          const totalBridgeReward = bridgeOperatorBonusPerBlock.mul(2); // called submitBlockReward 2 times
          expect(balanceDiff).eq(totalBridgeReward.div(await roninValidatorSet.totalBlockProducers()));
          expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
            5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
          );
          await expect(await roninValidatorSet.totalDeprecatedReward()).equal(0);
          await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
          await expect(tx!).emit(roninValidatorSet, 'DeprecatedRewardRecycled').withArgs(stakingVesting.address, 5200);
          lastPeriod = await roninValidatorSet.currentPeriod();
          await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
        }
      });

      it('Should be able to record delegating reward for a successful period', async () => {
        let tx: ContractTransaction;
        const balance = await treasury.getBalance();
        await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
        await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();

        epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });
        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);

        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
        await RoninValidatorSet.expects.emitStakingRewardDistributedEvent(
          tx!,
          blockProducerBonusPerBlock.add(100).div(100).mul(99)
        );

        const balanceDiff = (await treasury.getBalance()).sub(balance);
        const expectingBalanceDiff = blockProducerBonusPerBlock
          .add(100)
          .div(100)
          .add(bridgeOperatorBonusPerBlock.div(await roninValidatorSet.totalBlockProducers()));
        expect(balanceDiff).eq(expectingBalanceDiff);

        let _rewardFromBonus = blockProducerBonusPerBlock.div(100).mul(99).mul(2);
        let _rewardFromSubmission = BigNumber.from(100).div(100).mul(99).mul(3);
        expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
          _rewardFromBonus.add(_rewardFromSubmission)
        );
      });

      it('Should not allocate reward for the slashed validator', async () => {
        let tx: ContractTransaction;
        const balance = await treasury.getBalance();
        await slashIndicator.slashMisdemeanor(consensusAddr.address);
        tx = await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
        await expect(tx)
          .to.emit(roninValidatorSet, 'BlockRewardDeprecated')
          .withArgs(consensusAddr.address, 100, BlockRewardDeprecatedType.UNAVAILABILITY);
        await expect(await roninValidatorSet.totalDeprecatedReward()).equal(100);
        await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();

        epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });

        const balanceDiff = (await treasury.getBalance()).sub(balance);
        expect(balanceDiff).eq(bridgeOperatorBonusPerBlock.div(await roninValidatorSet.totalBlockProducers()));

        let _rewardFromBonus = blockProducerBonusPerBlock.div(100).mul(99).mul(2);
        let _rewardFromSubmission = BigNumber.from(100).div(100).mul(99).mul(3);
        expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
          _rewardFromBonus.add(_rewardFromSubmission)
        );

        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
      });
    });
  });

  describe('Recycle deprecated rewards', async () => {
    before(async () => {
      await expect(() => stakingVesting.receiveRON({ value: topUpAmount })).changeEtherBalance(
        stakingVesting.address,
        topUpAmount
      );
    });

    it('Should the slashed amount transfer back to staking vesting contract', async () => {
      let tx: ContractTransaction;
      const stakingVestingBalance = await ethers.provider.getBalance(stakingVesting.address);

      expect(await roninValidatorSet.totalDeprecatedReward()).equal(0);

      let slashTx;
      await expect(
        async () =>
          (slashTx = slashIndicator
            .connect(consensusAddr)
            .slashDoubleSign(validatorCandidates[2].consensusAddr.address, '0x', '0x'))
      ).changeEtherBalances(
        [stakingContract.address, roninValidatorSet.address],
        [BigNumber.from(0).sub(slashDoubleSignAmount), slashDoubleSignAmount]
      );

      await expect(slashTx).not.emit(stakingContract, 'StakingAmountTransferFailed');

      await expect(slashTx)
        .emit(slashIndicator, 'Slashed')
        .withArgs(validatorCandidates[2].consensusAddr.address, SlashType.DOUBLE_SIGNING, lastPeriod);
      expect(await roninValidatorSet.totalDeprecatedReward()).equal(slashDoubleSignAmount);

      currentValidatorSet.splice(-1, 1, validatorCandidates[1].consensusAddr.address);

      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      epoch = (await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber())).add(1);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      const stakingVestingBalanceDiff = (await ethers.provider.getBalance(stakingVesting.address)).sub(
        stakingVestingBalance
      );
      expect(stakingVestingBalanceDiff).eq(slashDoubleSignAmount);

      expect(await roninValidatorSet.totalDeprecatedReward()).equal(0);
      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      await expect(tx!)
        .emit(roninValidatorSet, 'DeprecatedRewardRecycled')
        .withArgs(stakingVesting.address, slashDoubleSignAmount);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
    });
  });
});
