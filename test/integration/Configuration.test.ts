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
  MainchainGovernanceAdmin__factory,
  MainchainGovernanceAdmin,
} from '../../src/types';
import { initTest, InitTestInput } from '../helpers/fixture';
import { MAX_UINT255, randomAddress } from '../../src/utils';
import { createManyTrustedOrganizationAddressSets, TrustedOrganizationAddressSet } from '../helpers/address-set-types';
import { compareBigNumbers, getRoles } from '../helpers/utils';

let stakingVestingContract: StakingVesting;
let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;
let roninTrustedOrganizationContract: RoninTrustedOrganization;
let roninGovernanceAdminContract: RoninGovernanceAdmin;
let mainchainGovernanceAdminContract: MainchainGovernanceAdmin;
let bridgeTrackingContract: BridgeTracking;

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
  mainchainGovernanceAdminArguments: {
    roleSetter: ethers.constants.AddressZero,
    relayers: [],
  },
  governanceAdminArguments: {
    proposalExpiryDuration: 60 * 60 * 24 * 14,
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
      mainchainGovernanceAdminAddress,
      bridgeTrackingAddress,
    } = await initTest('Configuration')(config);

    roninGovernanceAdminContract = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    mainchainGovernanceAdminContract = MainchainGovernanceAdmin__factory.connect(
      mainchainGovernanceAdminAddress,
      deployer
    );
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
  });

  it('Should the RoninGovernanceAdmin contract set configs correctly', async () => {
    expect(await roninGovernanceAdminContract.getContract(getRoles('RONIN_TRUSTED_ORGANIZATION_CONTRACT'))).eq(
      roninTrustedOrganizationContract.address
    );
    expect(await roninGovernanceAdminContract.getContract(getRoles('BRIDGE_CONTRACT'))).eq(config.bridgeContract);
    expect(await roninGovernanceAdminContract.getProposalExpiryDuration()).eq(
      config.governanceAdminArguments?.proposalExpiryDuration
    );
  });

  it('Should the MainchainGovernanceAdmin contract set configs correctly', async () => {
    expect(await mainchainGovernanceAdminContract.getProposalExpiryDuration()).eq(MAX_UINT255);
  });

  it('Should the Maintenance contract set configs correctly', async () => {
    expect(await maintenanceContract.getContract(getRoles('VALIDATOR_CONTRACT'))).eq(validatorContract.address);
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
    expect(await maintenanceContract.maxSchedules()).eq(config.maintenanceArguments!.maxSchedules);
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
    expect(await slashContract.getContract(getRoles('VALIDATOR_CONTRACT'))).to.eq(validatorContract.address);
    expect(await slashContract.getContract(getRoles('MAINTENANCE_CONTRACT'))).to.eq(maintenanceContract.address);
    expect(await slashContract.getContract(getRoles('RONIN_TRUSTED_ORGANIZATION_CONTRACT'))).to.eq(
      roninTrustedOrganizationContract.address
    );
    expect(await slashContract.getContract(getRoles('GOVERNANCE_ADMIN_CONTRACT'))).to.eq(
      roninGovernanceAdminContract.address
    );
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
    expect(await stakingContract.getContract(getRoles('VALIDATOR_CONTRACT'))).to.eq(validatorContract.address);
    expect(await stakingContract.minValidatorStakingAmount()).to.eq(config.stakingArguments?.minValidatorStakingAmount);
    expect(await stakingContract.cooldownSecsToUndelegate()).to.eq(config.stakingArguments?.cooldownSecsToUndelegate);
    expect(await stakingContract.waitingSecsToRevoke()).to.eq(config.stakingArguments?.waitingSecsToRevoke);
  });

  it('Should the StakingVestingContract contract set configs correctly', async () => {
    expect(await stakingVestingContract.getContract(getRoles('VALIDATOR_CONTRACT'))).eq(validatorContract.address);
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
    expect(await validatorContract.getContract(getRoles('SLASH_INDICATOR_CONTRACT'))).to.eq(slashContract.address);
    expect(await validatorContract.getContract(getRoles('STAKING_CONTRACT'))).to.eq(stakingContract.address);
    expect(await validatorContract.getContract(getRoles('STAKING_VESTING_CONTRACT'))).to.eq(
      stakingVestingContract.address
    );
    expect(await validatorContract.getContract(getRoles('MAINTENANCE_CONTRACT'))).to.eq(maintenanceContract.address);
    expect(await validatorContract.getContract(getRoles('RONIN_TRUSTED_ORGANIZATION_CONTRACT'))).to.eq(
      roninTrustedOrganizationContract.address
    );
    expect(await validatorContract.maxValidatorNumber()).to.eq(config.roninValidatorSetArguments?.maxValidatorNumber);
    expect(await validatorContract.maxValidatorCandidate()).to.eq(
      config.roninValidatorSetArguments?.maxValidatorCandidate
    );
    expect(await validatorContract.maxPrioritizedValidatorNumber()).to.eq(
      config.roninValidatorSetArguments?.maxPrioritizedValidatorNumber
    );
    expect(await validatorContract.minEffectiveDaysOnwards()).to.eq(
      config.roninValidatorSetArguments?.minEffectiveDaysOnwards
    );
    expect(await validatorContract.numberOfBlocksInEpoch()).to.eq(
      config.roninValidatorSetArguments?.numberOfBlocksInEpoch
    );
  });

  it('Should the BridgeTracking contract set configs correctly', async () => {
    expect(await bridgeTrackingContract.getContract(getRoles('BRIDGE_CONTRACT'))).to.eq(config.bridgeContract);
    expect(await bridgeTrackingContract.getContract(getRoles('VALIDATOR_CONTRACT'))).to.eq(validatorContract.address);
    expect(await bridgeTrackingContract.startedAtBlock()).to.eq(config.startedAtBlock);
  });
});
