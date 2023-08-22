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

let roninValidatorSet: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let fastFinalityTracking: FastFinalityTracking;
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
const fastFinalityRewardPercent = BigNumber.from(5_00); // 5%
const zeroTopUpAmount = 0;
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const proposalExpiryDuration = 60;

describe('Ronin Validator Set: Fast Finality test', () => {
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

    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
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
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);
    await roninValidatorSet.initEpoch();
    await roninValidatorSet.initializeV3(fastFinalityTrackingAddress);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);

    await stakingVesting.initializeV3(fastFinalityRewardPercent);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Configuration test', async () => {
    it('Should the Staking Vesting contract config percent of fast finality reward correctly', async () => {
      expect(await stakingVesting.fastFinalityRewardPercentage()).eq(fastFinalityRewardPercent);
    });
  });
});
