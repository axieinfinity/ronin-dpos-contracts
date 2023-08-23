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
  FastFinalityTracking__factory,
  FastFinalityTracking,
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

let validatorContract: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let fastFinalityTracking: FastFinalityTracking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
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

let localEpochController: EpochController;

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
const fastFinalityRewardPercent = BigNumber.from(5_00); // 5%
const zeroTopUpAmount = 0;
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const proposalExpiryDuration = 60;

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
        topupAmount: zeroTopUpAmount,
        fastFinalityRewardPercent,
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

    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    fastFinalityTracking = FastFinalityTracking__factory.connect(fastFinalityTrackingAddress, deployer);
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
          1,
          { value: minValidatorStakingAmount.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    await EpochController.setTimestampToPeriodEnding();
    epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
    lastPeriod = await validatorContract.currentPeriod();
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

  describe('Fast Finality tracking', async () => {
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });
    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
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
  });
});
