import { expect } from 'chai';
import { BigNumber, Transaction } from 'ethers';
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
  FastFinalityTracking__factory,
  FastFinalityTracking,
} from '../../../src/types';
import { EpochController } from '../helpers/ronin-validator-set';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { mineBatchTxs } from '../helpers/utils';

let validatorContract: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let fastFinalityTracking: FastFinalityTracking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

let epoch: BigNumber;

let snapshotId: string;

const waitingSecsToRevoke = 3 * 86400;
const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 4;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const blockProducerBonusPerBlock = BigNumber.from(2000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);
const fastFinalityRewardPercent = BigNumber.from(5_00); // 5%
const topupAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const proposalExpiryDuration = 60;
const numberOfBlocksInEpoch = 10;

describe('Ronin Validator Set: Fast Finality test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
      fastFinalityTrackingAddress,
    } = await initTest('RoninValidatorSet-FastFinality')({
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
        topupAmount,
        fastFinalityRewardPercent,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxValidatorCandidate,
        numberOfBlocksInEpoch,
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

    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    fastFinalityTracking = FastFinalityTracking__factory.connect(
      fastFinalityTrackingAddress,
      validatorCandidates[0].consensusAddr
    );
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initEpoch();

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);

    await validatorContract.initializeV3(fastFinalityTrackingAddress);
    await stakingVesting.initializeV3(fastFinalityRewardPercent);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          100_00,
          { value: minValidatorStakingAmount.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    await EpochController.setTimestampToPeriodEnding();
    epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
    await mineBatchTxs(async () => {
      await validatorContract.endEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
    });
    expect(await validatorContract.getValidators()).deep.equal(validatorCandidates.map((_) => _.consensusAddr.address));
    await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Configuration test', async () => {
    it('Should the Staking Vesting contract config percent of fast finality reward correctly', async () => {
      expect(await stakingVesting.fastFinalityRewardPercentage()).eq(fastFinalityRewardPercent);
    });
  });

  describe('Fast Finality Tracking', async () => {
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should not coinbase cannot call record vote', async () => {
      await expect(
        fastFinalityTracking.connect(coinbase).recordFinality(validatorCandidates.map((_) => _.consensusAddr.address))
      ).revertedWithCustomError(fastFinalityTracking, 'ErrCallerMustBeCoinbase');
    });

    it('Should record the fast finality in the first block', async () => {
      epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
      await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
    });

    it('Should get correctly the fast finality vote track', async () => {
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal(validatorCandidates.map((_) => 1));
    });

    it('Should record the fast finality in the second block', async () => {
      await fastFinalityTracking.recordFinality([validatorCandidates[0].consensusAddr.address]);
    });

    it('Should get correctly the fast finality info', async () => {
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal([2, ...validatorCandidates.slice(1).map((_) => 1)]);
    });

    it('Should the fast finality is reset in the new epoch', async () => {
      await mineBatchTxs(async () => {
        await validatorContract.endEpoch();
        await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
      });

      // Query for the previous epoch in the new epoch
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal([2, ...validatorCandidates.slice(1).map((_) => 1)]);

      epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
      // Query for the new epoch in the new epoch
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal(validatorCandidates.map((_) => 0));
    });

    it('Should the fast finality track correctly in the new epoch', async () => {
      await fastFinalityTracking.recordFinality([0, 1, 2].map((i) => validatorCandidates[i].consensusAddr.address));
      await fastFinalityTracking.recordFinality([1, 2, 3].map((i) => validatorCandidates[i].consensusAddr.address));
      await fastFinalityTracking.recordFinality([0, 2, 3].map((i) => validatorCandidates[i].consensusAddr.address));
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal([2, 2, 3, 2]);
    });

    it.skip('Should the fast finality track correctly the duplicated inputs', async () => {
      await mineBatchTxs(async () => {
        await validatorContract.endEpoch();
        await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
      });

      await fastFinalityTracking.recordFinality([1, 2, 2].map((i) => validatorCandidates[i].consensusAddr.address));
      await fastFinalityTracking.recordFinality([2, 2, 1].map((i) => validatorCandidates[i].consensusAddr.address));
      await fastFinalityTracking.recordFinality(
        [0, 1, 2, 2, 2, 2, 2].map((i) => validatorCandidates[i].consensusAddr.address)
      );
      expect(
        await fastFinalityTracking.getManyFinalityVoteCounts(
          epoch,
          validatorCandidates.map((_) => _.consensusAddr.address)
        )
      ).deep.equal([1, 3, 3, 0]);
    });

    it('Should not record twice in one block', async () => {
      await mineBatchTxs(async () => {
        await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
        let duplicatedRecordTracking = fastFinalityTracking.recordFinality(
          validatorCandidates.map((_) => _.consensusAddr.address)
        );
        await expect(duplicatedRecordTracking).revertedWithCustomError(fastFinalityTracking, 'ErrOncePerBlock');
      });
    });
  });

  describe('Fast Finality Reward', async () => {
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    describe('Record QC vote for all validators in all blocks of epoch', async () => {
      let tx: Transaction;
      it('Should equally dispense fast finality voting reward', async () => {
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        // Record for all blocks except the last block
        for (let i = 0; i < numberOfBlocksInEpoch - 1; i++) {
          await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
          await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward();
        }

        await EpochController.setTimestampToPeriodEnding();

        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          // Record for the last block
          await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
          await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        expect(
          await fastFinalityTracking.getManyFinalityVoteCounts(
            epoch,
            validatorCandidates.map((_) => _.consensusAddr.address)
          )
        ).deep.equal(validatorCandidates.map((_) => numberOfBlocksInEpoch));

        let rewardEach = blockProducerBonusPerBlock
          .mul(numberOfBlocksInEpoch)
          .mul(fastFinalityRewardPercent)
          .div(100_00)
          .div(4);

        await expect(tx).emit(validatorContract, 'WrappedUpEpoch').withArgs(anyValue, epoch, true);

        let totalMiningReward = blockProducerBonusPerBlock
          .mul(numberOfBlocksInEpoch)
          .mul(BigNumber.from(100_00).sub(fastFinalityRewardPercent))
          .div(100_00);

        await expect(tx)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, anyValue, totalMiningReward);

        for (let i = 0; i < validatorCandidates.length; i++) {
          await expect(tx)
            .emit(validatorContract, 'FastFinalityRewardDistributed')
            .withArgs(validatorCandidates[i].consensusAddr.address, anyValue, rewardEach);
        }
      });

      it('Should no reward get recycled', async () => {
        await expect(tx).not.emit(validatorContract, 'DeprecatedRewardRecycled');
      });
    });

    describe('Some validators missing QC vote', async () => {
      let tx: Transaction;
      let leftoverFastFinalityReward: BigNumber;
      it('Should share reward based on validator tracking', async () => {
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        // Record for first 5 blocks for all validators except the first one
        for (let i = 1; i <= numberOfBlocksInEpoch / 2; i++) {
          // let [1; 5]
          await fastFinalityTracking.recordFinality(validatorCandidates.slice(1).map((_) => _.consensusAddr.address));
          await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward();
        }

        // Record for later 5 blocks for all validators
        for (let i = numberOfBlocksInEpoch / 2 + 1; i < numberOfBlocksInEpoch; i++) {
          // let [6; 9]
          await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
          await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward();
        }

        await EpochController.setTimestampToPeriodEnding();

        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          // Record for the last block
          await fastFinalityTracking.recordFinality(validatorCandidates.map((_) => _.consensusAddr.address));
          await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        expect(
          await fastFinalityTracking.getManyFinalityVoteCounts(
            epoch,
            validatorCandidates.map((_) => _.consensusAddr.address)
          )
        ).deep.equal([numberOfBlocksInEpoch / 2, ...validatorCandidates.slice(1).map((_) => numberOfBlocksInEpoch)]);

        let rewardEach = blockProducerBonusPerBlock
          .mul(numberOfBlocksInEpoch)
          .mul(fastFinalityRewardPercent)
          .div(100_00)
          .div(4);

        await expect(tx).emit(validatorContract, 'WrappedUpEpoch').withArgs(anyValue, epoch, true);

        let totalMiningReward = blockProducerBonusPerBlock
          .mul(numberOfBlocksInEpoch)
          .mul(BigNumber.from(100_00).sub(fastFinalityRewardPercent))
          .div(100_00);

        await expect(tx)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, anyValue, totalMiningReward);

        let validator0FastFinalityReward = rewardEach.div(2);
        await expect(tx)
          .emit(validatorContract, 'FastFinalityRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, anyValue, rewardEach.div(2));

        leftoverFastFinalityReward = rewardEach.sub(validator0FastFinalityReward);

        for (let i = 1; i < validatorCandidates.length; i++) {
          await expect(tx)
            .emit(validatorContract, 'FastFinalityRewardDistributed')
            .withArgs(validatorCandidates[i].consensusAddr.address, anyValue, rewardEach);
        }
      });

      it('Should unused reward of fast finality get recycled', async () => {
        await expect(tx)
          .emit(validatorContract, 'DeprecatedRewardRecycled')
          .withArgs(anyValue, leftoverFastFinalityReward);
      });
    });
  });
});
