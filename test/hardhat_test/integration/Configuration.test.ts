import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber } from 'ethers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  Maintenance__factory,
  Maintenance,
  StakingVesting__factory,
  StakingVesting,
  RoninTrustedOrganization__factory,
  RoninTrustedOrganization,
  RoninGovernanceAdmin__factory,
  RoninGovernanceAdmin,
  BridgeTracking__factory,
  BridgeTracking,
  RoninBridgeManager,
  RoninBridgeManager__factory,
  BridgeReward,
  BridgeReward__factory,
  BridgeSlash,
  BridgeSlash__factory,
} from '../../../src/types';
import { initTest, InitTestInput } from '../helpers/fixture';
import { MAX_UINT255, randomAddress } from '../../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { ContractType, compareBigNumbers } from '../helpers/utils';

let stakingVestingContract: StakingVesting;
let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;
let roninTrustedOrganizationContract: RoninTrustedOrganization;
let roninGovernanceAdminContract: RoninGovernanceAdmin;
let bridgeTrackingContract: BridgeTracking;
let bridgeManagerContract: RoninBridgeManager;
let bridgeRewardContract: BridgeReward;
let bridgeSlashContract: BridgeSlash;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];

const config: InitTestInput = {
  bridgeContract: randomAddress(),
  startedAtBlock: Math.floor(Math.random() * 1_000_000),

  maintenanceArguments: {
    minMaintenanceDurationInBlock: 100,
    maxMaintenanceDurationInBlock: 1000,
    minOffsetToStartSchedule: 200,
    maxOffsetToStartSchedule: 200 * 7,
    maxSchedules: 2,
  },

  stakingArguments: {
    minValidatorStakingAmount: BigNumber.from(100),
    cooldownSecsToUndelegate: 100,
    waitingSecsToRevoke: 1000,
  },
  stakingVestingArguments: {
    blockProducerBonusPerBlock: 1_000,
    bridgeOperatorBonusPerBlock: 1_100,
    topupAmount: BigNumber.from(10_000_000),
  },
  slashIndicatorArguments: {
    bridgeOperatorSlashing: {
      missingVotesRatioTier1: 10_00, // 10%
      missingVotesRatioTier2: 20_00, // 20%
      jailDurationForMissingVotesRatioTier2: 28800 * 2,
      skipBridgeOperatorSlashingThreshold: 7777777,
    },
    bridgeVotingSlashing: {
      bridgeVotingThreshold: 28800 * 3,
      bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000),
    },
    doubleSignSlashing: {
      slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10),
      doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
      doubleSigningOffsetLimitBlock: 28800 * 7,
    },
    unavailabilitySlashing: {
      unavailabilityTier1Threshold: 5,
      unavailabilityTier2Threshold: 10,
      slashAmountForUnavailabilityTier2Threshold: BigNumber.from(10).pow(18).mul(1),
      jailDurationForUnavailabilityTier2Threshold: 28800 * 2,
    },
    creditScore: {
      gainCreditScore: 50,
      maxCreditScore: 600,
      bailOutCostMultiplier: 5,
      cutOffPercentageAfterBailout: 50_00, // 50%
    },
  },
  roninValidatorSetArguments: {
    maxValidatorNumber: 4,
    maxPrioritizedValidatorNumber: 0,
    numberOfBlocksInEpoch: 600,
    maxValidatorCandidate: 10,
    minEffectiveDaysOnwards: 7,
  },
  roninTrustedOrganizationArguments: {
    trustedOrganizations: [],
    numerator: 0,
    denominator: 1,
  },
  governanceAdminArguments: {
    proposalExpiryDuration: 60 * 60 * 24 * 14,
  },
  bridgeManagerArguments: {
    numerator: 70,
    denominator: 100,
    members: [],
    expiryDuration: 60 * 60 * 24 * 14, // 14 days
  },
};

describe('[Integration] Configuration check', () => {
  before(async () => {
    [coinbase, deployer, ...signers] = await ethers.getSigners();

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));

    config.roninTrustedOrganizationArguments!.trustedOrganizations = trustedOrgs.map((v) => ({
      consensusAddr: v.consensusAddr.address,
      governor: v.governor.address,
      bridgeVoter: v.bridgeVoter.address,
      weight: 100,
      addedBlock: 0,
    }));
    const {
      maintenanceContractAddress,
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      stakingVestingContractAddress,
      roninTrustedOrganizationAddress,
      roninGovernanceAdminAddress,
      bridgeTrackingAddress,
      bridgeRewardAddress,
      bridgeSlashAddress,
      roninBridgeManagerAddress,
    } = await initTest('Configuration')(config);

    roninGovernanceAdminContract = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    maintenanceContract = Maintenance__factory.connect(maintenanceContractAddress, deployer);
    roninTrustedOrganizationContract = RoninTrustedOrganization__factory.connect(
      roninTrustedOrganizationAddress,
      deployer
    );
    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    stakingVestingContract = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    validatorContract = RoninValidatorSet__factory.connect(validatorContractAddress, deployer);
    bridgeTrackingContract = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    bridgeRewardContract = BridgeReward__factory.connect(bridgeRewardAddress, deployer);
    bridgeSlashContract = BridgeSlash__factory.connect(bridgeSlashAddress, deployer);
    bridgeManagerContract = RoninBridgeManager__factory.connect(roninBridgeManagerAddress, deployer);
  });

  it('Should the RoninGovernanceAdmin contract set configs correctly', async () => {
    expect(await roninGovernanceAdminContract.getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).eq(
      roninTrustedOrganizationContract.address
    );
    expect(await roninGovernanceAdminContract.getProposalExpiryDuration()).eq(
      config.governanceAdminArguments?.proposalExpiryDuration
    );
  });

  it('Should the BridgeAdmin contract set configs correctly', async () => {
    expect(await bridgeManagerContract.getContract(ContractType.BRIDGE)).eq(config.bridgeContract);
    expect(await bridgeManagerContract.getProposalExpiryDuration()).eq(config.bridgeManagerArguments?.expiryDuration);
  });

  it('Should the Maintenance contract set configs correctly', async () => {
    expect(await maintenanceContract.getContract(ContractType.VALIDATOR)).eq(validatorContract.address);
    expect(await maintenanceContract.minMaintenanceDurationInBlock()).eq(
      config.maintenanceArguments?.minMaintenanceDurationInBlock
    );
    expect(await maintenanceContract.maxMaintenanceDurationInBlock()).eq(
      config.maintenanceArguments?.maxMaintenanceDurationInBlock
    );
    expect(await maintenanceContract.minOffsetToStartSchedule()).eq(
      config.maintenanceArguments!.minOffsetToStartSchedule
    );
    expect(await maintenanceContract.maxOffsetToStartSchedule()).eq(
      config.maintenanceArguments!.maxOffsetToStartSchedule
    );
    expect(await maintenanceContract.maxSchedule()).eq(config.maintenanceArguments!.maxSchedules);
  });

  it('Should the RoninTrustedOrganization contract set configs correctly', async () => {
    expect(
      (await roninTrustedOrganizationContract.getAllTrustedOrganizations()).map(
        ({ consensusAddr, governor, bridgeVoter, weight }) => ({
          consensusAddr,
          governor,
          bridgeVoter,
          weight,
          addedBlock: undefined,
        })
      )
    ).deep.equal(
      trustedOrgs.map((v) => ({
        consensusAddr: v.consensusAddr.address,
        governor: v.governor.address,
        bridgeVoter: v.bridgeVoter.address,
        weight: BigNumber.from(100),
        addedBlock: undefined,
      }))
    );
    expect(await roninTrustedOrganizationContract.getThreshold()).deep.equal(
      [config.roninTrustedOrganizationArguments?.numerator, config.roninTrustedOrganizationArguments?.denominator].map(
        BigNumber.from
      )
    );
  });

  it('Should the SlashIndicatorContract contract set configs correctly', async () => {
    expect(await slashContract.getContract(ContractType.VALIDATOR)).to.eq(validatorContract.address);
    expect(await slashContract.getContract(ContractType.MAINTENANCE)).to.eq(maintenanceContract.address);
    expect(await slashContract.getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).to.eq(
      roninTrustedOrganizationContract.address
    );
    expect(await slashContract.getContract(ContractType.GOVERNANCE_ADMIN)).to.eq(roninGovernanceAdminContract.address);
    await compareBigNumbers(
      await slashContract.getBridgeOperatorSlashingConfigs(),
      [
        config.slashIndicatorArguments?.bridgeOperatorSlashing?.missingVotesRatioTier1,
        config.slashIndicatorArguments?.bridgeOperatorSlashing?.missingVotesRatioTier2,
        config.slashIndicatorArguments?.bridgeOperatorSlashing?.jailDurationForMissingVotesRatioTier2,
        config.slashIndicatorArguments?.bridgeOperatorSlashing?.skipBridgeOperatorSlashingThreshold,
      ].map(BigNumber.from)
    );
    await compareBigNumbers(
      await slashContract.getBridgeVotingSlashingConfigs(),
      [
        config.slashIndicatorArguments?.bridgeVotingSlashing?.bridgeVotingThreshold,
        config.slashIndicatorArguments?.bridgeVotingSlashing?.bridgeVotingSlashAmount,
      ].map(BigNumber.from)
    );
    await compareBigNumbers(
      await slashContract.getDoubleSignSlashingConfigs(),
      [
        config.slashIndicatorArguments?.doubleSignSlashing?.slashDoubleSignAmount,
        config.slashIndicatorArguments?.doubleSignSlashing?.doubleSigningJailUntilBlock,
        config.slashIndicatorArguments?.doubleSignSlashing?.doubleSigningOffsetLimitBlock,
      ].map(BigNumber.from)
    );
    await compareBigNumbers(
      await slashContract.getUnavailabilitySlashingConfigs(),
      [
        config.slashIndicatorArguments?.unavailabilitySlashing?.unavailabilityTier1Threshold,
        config.slashIndicatorArguments?.unavailabilitySlashing?.unavailabilityTier2Threshold,
        config.slashIndicatorArguments?.unavailabilitySlashing?.slashAmountForUnavailabilityTier2Threshold,
        config.slashIndicatorArguments?.unavailabilitySlashing?.jailDurationForUnavailabilityTier2Threshold,
      ].map(BigNumber.from)
    );
    await compareBigNumbers(
      await slashContract.getCreditScoreConfigs(),
      [
        config.slashIndicatorArguments?.creditScore?.gainCreditScore,
        config.slashIndicatorArguments?.creditScore?.maxCreditScore,
        config.slashIndicatorArguments?.creditScore?.bailOutCostMultiplier,
        config.slashIndicatorArguments?.creditScore?.cutOffPercentageAfterBailout,
      ].map(BigNumber.from)
    );
  });

  it('Should the StakingContract contract set configs correctly', async () => {
    expect(await stakingContract.getContract(ContractType.VALIDATOR)).to.eq(validatorContract.address);
    expect(await stakingContract.minValidatorStakingAmount()).to.eq(config.stakingArguments?.minValidatorStakingAmount);
    expect(await stakingContract.cooldownSecsToUndelegate()).to.eq(config.stakingArguments?.cooldownSecsToUndelegate);
    expect(await stakingContract.waitingSecsToRevoke()).to.eq(config.stakingArguments?.waitingSecsToRevoke);
  });

  it('Should the StakingVestingContract contract set configs correctly', async () => {
    expect(await stakingVestingContract.getContract(ContractType.VALIDATOR)).eq(validatorContract.address);
    expect(await stakingVestingContract.blockProducerBlockBonus(0)).eq(
      config.stakingVestingArguments?.blockProducerBonusPerBlock
    );
    expect(await stakingVestingContract.blockProducerBlockBonus(Math.floor(Math.random() * 1_000_000))).eq(
      config.stakingVestingArguments?.blockProducerBonusPerBlock
    );
    expect(await stakingVestingContract.bridgeOperatorBlockBonus(0)).eq(
      config.stakingVestingArguments?.bridgeOperatorBonusPerBlock
    );
    expect(await stakingVestingContract.bridgeOperatorBlockBonus(Math.floor(Math.random() * 1_000_000))).eq(
      config.stakingVestingArguments?.bridgeOperatorBonusPerBlock
    );
  });

  it('Should the ValidatorSetContract contract set configs correctly', async () => {
    expect(await validatorContract.getContract(ContractType.SLASH_INDICATOR)).to.eq(slashContract.address);
    expect(await validatorContract.getContract(ContractType.STAKING)).to.eq(stakingContract.address);
    expect(await validatorContract.getContract(ContractType.STAKING_VESTING)).to.eq(stakingVestingContract.address);
    expect(await validatorContract.getContract(ContractType.MAINTENANCE)).to.eq(maintenanceContract.address);
    expect(await validatorContract.getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).to.eq(
      roninTrustedOrganizationContract.address
    );
    expect(await validatorContract.maxValidatorNumber()).to.eq(config.roninValidatorSetArguments?.maxValidatorNumber);
    expect(await validatorContract.maxValidatorCandidate()).to.eq(
      config.roninValidatorSetArguments?.maxValidatorCandidate
    );
    expect(await validatorContract.maxPrioritizedValidatorNumber()).to.eq(
      config.roninValidatorSetArguments?.maxPrioritizedValidatorNumber
    );
    expect(await validatorContract.minEffectiveDaysOnward()).to.eq(
      config.roninValidatorSetArguments?.minEffectiveDaysOnwards
    );
    expect(await validatorContract.numberOfBlocksInEpoch()).to.eq(
      config.roninValidatorSetArguments?.numberOfBlocksInEpoch
    );
  });

  it('Should the BridgeTracking contract set configs correctly', async () => {
    expect(await bridgeTrackingContract.getContract(ContractType.BRIDGE)).to.eq(config.bridgeContract);
    expect(await bridgeTrackingContract.getContract(ContractType.VALIDATOR)).to.eq(validatorContract.address);
    expect(await bridgeTrackingContract.startedAtBlock()).to.eq(config.startedAtBlock);
  });

  it('Should the BridgeReward contract set configs correctly', async () => {
    expect(await bridgeRewardContract.getContract(ContractType.BRIDGE_MANAGER)).to.eq(bridgeManagerContract.address);
    expect(await bridgeRewardContract.getContract(ContractType.BRIDGE_TRACKING)).to.eq(bridgeTrackingContract.address);
    expect(await bridgeRewardContract.getContract(ContractType.BRIDGE_SLASH)).to.eq(bridgeSlashContract.address);
  });

  it('Should the BridgeSlash contract set configs correctly', async () => {
    expect(await bridgeSlashContract.getContract(ContractType.BRIDGE_MANAGER)).to.eq(bridgeManagerContract.address);
    expect(await bridgeSlashContract.getContract(ContractType.BRIDGE_TRACKING)).to.eq(bridgeTrackingContract.address);
  });
});
