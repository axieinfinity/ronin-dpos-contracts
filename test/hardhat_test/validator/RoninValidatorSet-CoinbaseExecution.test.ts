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
} from '../../../src/types';
import { EpochController } from '../helpers/ronin-validator-set';
import { expects as RoninValidatorSetExpects } from '../helpers/ronin-validator-set';
import { expects as CandidateManagerExpects } from '../helpers/candidate-manager';
import { expects as StakingVestingExpects } from '../helpers/staking-vesting';
import { getLastBlockTimestamp, mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { BlockRewardDeprecatedType } from '../../../src/script/ronin-validator-set';
import { Address } from 'hardhat-deploy/dist/types';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { SlashType } from '../../../src/script/slash-indicator';
import { ProposalDetailStruct } from '../../../src/types/GovernanceAdmin';
import { VoteType } from '../../../src/script/proposal';

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

let snapshotId: string;

const dummyStakingMultiplier = 5;
const localValidatorCandidatesLength = 5;

const waitingSecsToRevoke = 3 * 86400;
const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 4;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const blockProducerBonusPerBlock = BigNumber.from(5000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);
const zeroTopUpAmount = 0;
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const proposalExpiryDuration = 60;

describe('Ronin Validator Set: Coinbase execution test', () => {
  before(async () => {
    [poolAdmin, consensusAddr, bridgeOperator, deployer, ...signers] = await ethers.getSigners();
    candidateAdmin = poolAdmin;
    treasury = poolAdmin;

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(
      signers.splice(0, localValidatorCandidatesLength * 3)
    );

    await network.provider.send('hardhat_setCoinbase', [consensusAddr.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
      fastFinalityTrackingAddress,
    } = await initTest('RoninValidatorSet-Coinbase')({
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
        waitingSecsToRevoke,
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
      governanceAdminArguments: {
        proposalExpiryDuration,
      },
    });

    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);
    await roninValidatorSet.initEpoch();
    await roninValidatorSet.initializeV3(fastFinalityTrackingAddress);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Wrapping up epoch sanity check', async () => {
    it('Should not be able to wrap up epoch using unauthorized account', async () => {
      await expect(roninValidatorSet.connect(deployer).wrapUpEpoch()).revertedWithCustomError(
        roninValidatorSet,
        'ErrCallerMustBeCoinbase'
      );
    });

    it('Should not be able to wrap up epoch when the epoch is not ending', async () => {
      await expect(roninValidatorSet.connect(consensusAddr).wrapUpEpoch()).revertedWithCustomError(
        roninValidatorSet,
        'ErrAtEndOfEpochOnly'
      );
    });

    it('Should be able to wrap up epoch when the epoch is ending', async () => {
      let tx: ContractTransaction;
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      let nextEpoch = epoch.add(1);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });
      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(tx!, lastPeriod, nextEpoch, []);
      expect(await roninValidatorSet.getValidators()).deep.equal([]);
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
            2_00,
            {
              value: minValidatorStakingAmount.add(i * dummyStakingMultiplier),
            }
          );
      }

      let tx: ContractTransaction;
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });
      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, false);
      expect(await roninValidatorSet.getValidators()).deep.equal([]);
      expect(await roninValidatorSet.getBlockProducers()).deep.equal([]);
      await expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
    });
  });

  describe('Wrapping up at the end of the period', async () => {
    let expectingValidatorsAddr: Address[];
    it('Should be able to wrap up epoch at end of period and sync validator set from staking contract', async () => {
      let tx: ContractTransaction;
      await EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      expectingValidatorsAddr = validatorCandidates // [candidates[4..1]]
        .slice(0, 4)
        .reverse()
        .map((_) => _.consensusAddr.address);

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, expectingValidatorsAddr);
      expect(await roninValidatorSet.getValidators()).deep.equal(expectingValidatorsAddr);
      expect(await roninValidatorSet.getBlockProducers()).deep.equal(expectingValidatorsAddr);
    });

    it('Should validator is set with correct flags', async () => {
      for (let validatorAddr of expectingValidatorsAddr) {
        expect(await roninValidatorSet.isBlockProducer(validatorAddr)).eq(
          true,
          `Wrong block producer flag for ${validatorAddr}`
        );
      }
    });

    it('Should non-validator is set with correct flags', async () => {
      expect(await roninValidatorSet.isBlockProducer(deployer.address)).eq(false);
    });

    it('Should be able to wrap up epoch at the end of period and pick top `maxValidatorNumber` to be validators', async () => {
      await stakingContract
        .connect(poolAdmin)
        .applyValidatorCandidate(candidateAdmin.address, consensusAddr.address, treasury.address, 1_00 /* 1% */, {
          value: minValidatorStakingAmount.mul(100),
        });
      for (let i = 4; i < localValidatorCandidatesLength; i++) {
        await stakingContract
          .connect(validatorCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            validatorCandidates[i].candidateAdmin.address,
            validatorCandidates[i].consensusAddr.address,
            validatorCandidates[i].treasuryAddr.address,
            2_00,
            {
              value: minValidatorStakingAmount.add(i * dummyStakingMultiplier),
            }
          );
      }
      expect((await roninValidatorSet.getValidatorCandidates()).length).eq(localValidatorCandidatesLength + 1);

      let tx: ContractTransaction;
      await EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        currentValidatorSet = [
          // [coinbase, candidates[4..2]]
          consensusAddr.address,
          ...[validatorCandidates[4], validatorCandidates[3], validatorCandidates[2]].map(
            (_) => _.consensusAddr.address
          ),
        ];
      });

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
      expect(await roninValidatorSet.getValidators()).deep.equal(currentValidatorSet);
      expect(await roninValidatorSet.getBlockProducers()).deep.equal(currentValidatorSet);
    });
  });

  describe('Setting new validator set', async () => {
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    describe('Case updating from [V100,V4,V3,V2] --> [V100,V3,V4,V2]', async () => {
      let expectingValidatorsAddr: Address[];
      it('Should the validator set is updated correctly', async () => {
        // [(V4: 20), (V3: 15), (V2: 10)] ---> [(V3: 21), (V4: 20), (V2: 10)]
        await stakingContract.connect(signers[0]).delegate(validatorCandidates[3].consensusAddr.address, { value: 6 });

        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await roninValidatorSet.currentPeriod();
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
          expectingValidatorsAddr = [
            // [coinbase, candidates[3], candidates[4], candidates[2]]
            consensusAddr.address,
            ...[validatorCandidates[3], validatorCandidates[4], validatorCandidates[2]].map(
              (_) => _.consensusAddr.address
            ),
          ];
        });

        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, expectingValidatorsAddr);
      });

      it('Should validator is set with correct flags', async () => {
        expect(await roninValidatorSet.getValidators()).deep.equal(expectingValidatorsAddr);
        expect(await roninValidatorSet.getBlockProducers()).deep.equal(expectingValidatorsAddr);
        for (let validatorAddr of expectingValidatorsAddr) {
          expect(await roninValidatorSet.isBlockProducer(validatorAddr)).eq(
            true,
            `Wrong block producer flag for ${validatorAddr}`
          );
        }
      });
    });
  });

  describe('Renunciation of candidates', async () => {
    let currValidator: ValidatorCandidateAddressSet;
    let unclaimedReward: BigNumber;
    let wrapupEpochTx: ContractTransaction;
    let balanceBefore: BigNumber;

    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
      currValidator = validatorCandidates.slice(-1)[0];
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should the validator can submit block reward and get claimble staking reward', async () => {
      expect(await stakingContract.getReward(currValidator.consensusAddr.address, currValidator.poolAdmin.address)).eq(
        0
      );
      await network.provider.send('hardhat_setCoinbase', [currValidator.consensusAddr.address]);
      let submitRewardTx = await roninValidatorSet
        .connect(currValidator.consensusAddr)
        .submitBlockReward({ value: 1000 });
      await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(
        submitRewardTx,
        currValidator.consensusAddr.address,
        1000,
        0
      );
      await network.provider.send('hardhat_setCoinbase', [consensusAddr.address]);

      let tx: ContractTransaction;
      await EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();

      unclaimedReward = await stakingContract.getReward(
        currValidator.consensusAddr.address,
        currValidator.poolAdmin.address
      );
      expect(unclaimedReward).gt(0);
    });

    it('Should the validator can request renounce', async () => {
      await stakingContract.connect(currValidator.poolAdmin).requestRenounce(currValidator.consensusAddr.address);
    });

    it('Should the validator is revoked at the end of the period', async () => {
      balanceBefore = await currValidator.poolAdmin.getBalance();

      await network.provider.send('evm_increaseTime', [waitingSecsToRevoke]);

      await EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        wrapupEpochTx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      await expect(wrapupEpochTx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      await CandidateManagerExpects.emitCandidatesRevokedEvent(wrapupEpochTx!, [currValidator.consensusAddr.address]);
      lastPeriod = await roninValidatorSet.currentPeriod();

      let balanceAfter = await currValidator.poolAdmin.getBalance();
      expect(balanceAfter.sub(balanceBefore)).eq(
        minValidatorStakingAmount.add(4 * dummyStakingMultiplier).add(unclaimedReward)
      );
    });

    it('Should the self-staking amount get refunded', async () => {
      await expect(wrapupEpochTx!)
        .emit(stakingContract, 'Unstaked')
        .withArgs(currValidator.consensusAddr.address, minValidatorStakingAmount.add(4 * dummyStakingMultiplier));
    });

    it('Should the unclaimed reward amount get transferred on revoke, and the claimable reward get reset', async () => {
      await expect(wrapupEpochTx!)
        .emit(stakingContract, 'RewardClaimed')
        .withArgs(currValidator.consensusAddr.address, currValidator.poolAdmin.address, unclaimedReward);

      expect(await stakingContract.getReward(currValidator.consensusAddr.address, currValidator.poolAdmin.address)).eq(
        0
      );
    });
  });

  describe('Recording and distributing rewards', async () => {
    describe('Sanity check', async () => {
      it('Should not be able to submit block reward using unauthorized account', async () => {
        await expect(roninValidatorSet.submitBlockReward()).revertedWithCustomError(
          roninValidatorSet,
          'ErrCallerMustBeCoinbase'
        );
      });
    });

    describe('Submit block reward when staking vesting is insufficient', async () => {
      it('Should be able to submit block reward using coinbase account and not receive bonuses', async () => {
        const tx = await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });

        epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(tx, consensusAddr.address, 100, 0);

        await expect(tx).not.emit(stakingVesting, 'BonusTransferred');
        await StakingVestingExpects.emitBonusTransferFailedEvent(
          tx,
          undefined,
          roninValidatorSet.address,
          blockProducerBonusPerBlock,
          BigNumber.from(0),
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

        await RoninValidatorSetExpects.emitBlockRewardSubmittedEvent(
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
          0
        );
      });

      it('Should be able to get right reward at the end of period', async () => {
        const balance = await treasury.getBalance();
        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();

        lastPeriod = await roninValidatorSet.currentPeriod();
        epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
        await RoninValidatorSetExpects.emitStakingRewardDistributedEvent(
          tx!,
          5148,
          currentValidatorSet,
          [5148, 0, 0, 0].map((_) => BigNumber.from(_))
        ); // (5000 + 100 + 100) * 99%
        await RoninValidatorSetExpects.emitMiningRewardDistributedEvent(
          tx!,
          consensusAddr.address,
          treasury.address,
          52
        ); // (5000 + 100 + 100) * 1%

        const balanceDiff = (await treasury.getBalance()).sub(balance);
        expect(balanceDiff).eq(52); // = (5000 + 100 + 100) * 1% + 9 = (52 + 9)
        expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
          5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
        );
      });

      // it('Should not allocate minting fee for the slashed validators, but allocate bridge reward', async () => {
      //   let tx: ContractTransaction;
      //   {
      //     const balance = await treasury.getBalance();
      //     await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
      //     tx = await slashIndicator.slashMisdemeanor(consensusAddr.address);
      //     await expect(tx)
      //       .emit(roninValidatorSet, 'ValidatorPunished')
      //       .withArgs(consensusAddr.address, lastPeriod, 0, 0, true, false);

      //     expect(await roninValidatorSet.totalDeprecatedReward()).equal(5100); // = 0 + (5000 + 100)

      //     epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      //     lastPeriod = await roninValidatorSet.currentPeriod();
      //     await mineBatchTxs(async () => {
      //       await roninValidatorSet.endEpoch();
      //       tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      //     });
      //     const balanceDiff = (await treasury.getBalance()).sub(balance);
      //     expect(balanceDiff).eq(0); // The delegators don't receives the new rewards until the period is ended
      //     expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
      //       5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
      //     );
      //     await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, false);
      //     await expect(tx!).not.emit(roninValidatorSet, 'ValidatorSetUpdated');
      //   }

      //   {
      //     const balance = await treasury.getBalance();
      //     await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
      //     await EpochController.setTimestampToPeriodEnding();

      //     epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      //     lastPeriod = await roninValidatorSet.currentPeriod();
      //     await mineBatchTxs(async () => {
      //       await roninValidatorSet.endEpoch();
      //       tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      //     });

      //     const balanceDiff = (await treasury.getBalance()).sub(balance);
      //     const totalBridgeReward = bridgeOperatorBonusPerBlock.mul(2); // called submitBlockReward 2 times
      //     expect(balanceDiff).eq(totalBridgeReward.div(await roninValidatorSet.totalBlockProducers()));
      //     expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
      //       5148 // (5000 + 100 + 100) * 99% = 99% of the reward, since the pool is only staked by the poolAdmin
      //     );
      //     await expect(await roninValidatorSet.totalDeprecatedReward()).equal(0);
      //     await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      //     await expect(tx!).emit(roninValidatorSet, 'DeprecatedRewardRecycled').withArgs(stakingVesting.address, 5200);
      //     lastPeriod = await roninValidatorSet.currentPeriod();
      //     await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
      //   }
      // });

      it('Should be able to record delegating reward for a successful period', async () => {
        let tx: ContractTransaction;
        const balance = await treasury.getBalance();
        await roninValidatorSet.connect(consensusAddr).submitBlockReward({ value: 100 });
        await EpochController.setTimestampToPeriodEnding();

        epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await roninValidatorSet.currentPeriod();
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });
        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);

        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
        await RoninValidatorSetExpects.emitStakingRewardDistributedEvent(
          tx!,
          blockProducerBonusPerBlock.add(100).div(100).mul(99),
          currentValidatorSet,
          [blockProducerBonusPerBlock.add(100).div(100).mul(99), 0, 0, 0].map((_) => BigNumber.from(_))
        );

        const balanceDiff = (await treasury.getBalance()).sub(balance);
        const expectingBalanceDiff = blockProducerBonusPerBlock.add(100).div(100);
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
        expect(await roninValidatorSet.totalDeprecatedReward()).equal(100);
        await EpochController.setTimestampToPeriodEnding();

        epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await roninValidatorSet.currentPeriod();
        await mineBatchTxs(async () => {
          await roninValidatorSet.endEpoch();
          tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
        });

        const balanceDiff = (await treasury.getBalance()).sub(balance);
        // expect(balanceDiff).eq(bridgeOperatorBonusPerBlock.div(await roninValidatorSet.totalBlockProducers()));

        let _rewardFromBonus = blockProducerBonusPerBlock.div(100).mul(99).mul(2);
        let _rewardFromSubmission = BigNumber.from(100).div(100).mul(99).mul(3);
        expect(await stakingContract.getReward(consensusAddr.address, poolAdmin.address)).eq(
          _rewardFromBonus.add(_rewardFromSubmission)
        );

        await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await roninValidatorSet.currentPeriod();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
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

      // --- Create proposal to slash double signing
      const latestTimestamp = await getLastBlockTimestamp();
      let calldata = governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
        slashIndicator.interface.encodeFunctionData('slashDoubleSign', [
          validatorCandidates[2].consensusAddr.address,
          ethers.utils.toUtf8Bytes('sampleHeader1'),
          ethers.utils.toUtf8Bytes('sampleHeader2'),
        ]),
      ]);
      let proposal: ProposalDetailStruct = await governanceAdminInterface.createProposal(
        latestTimestamp + proposalExpiryDuration,
        slashIndicator.address,
        0,
        calldata,
        500_000
      );
      let signatures = await governanceAdminInterface.generateSignatures(
        proposal,
        trustedOrgs.map((_) => _.governor)
      );
      let supports = signatures.map(() => VoteType.For);
      /// ---

      let slashTx;
      await expect(
        async () =>
          (slashTx = await governanceAdmin
            .connect(trustedOrgs[0].governor)
            .proposeProposalStructAndCastVotes(proposal, supports, signatures))
      ).changeEtherBalances(
        [stakingContract.address, roninValidatorSet.address],
        [BigNumber.from(0).sub(slashDoubleSignAmount), slashDoubleSignAmount]
      );

      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address)).to
        .true;
      await expect(slashTx).emit(governanceAdmin, 'ProposalExecuted');
      await expect(slashTx).not.emit(stakingContract, 'StakingAmountTransferFailed');

      await expect(slashTx)
        .emit(slashIndicator, 'Slashed')
        .withArgs(validatorCandidates[2].consensusAddr.address, SlashType.DOUBLE_SIGNING, lastPeriod);
      expect(await roninValidatorSet.totalDeprecatedReward()).equal(slashDoubleSignAmount);

      currentValidatorSet.splice(-1, 1, validatorCandidates[1].consensusAddr.address);

      await EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
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
      await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, currentValidatorSet);
    });
  });
});
