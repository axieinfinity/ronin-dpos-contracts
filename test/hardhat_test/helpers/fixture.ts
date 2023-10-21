import { BigNumber, BigNumberish } from 'ethers';
import { deployments, ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';

import { EpochController } from './ronin-validator-set';
import {
  generalMainchainConf,
  generalRoninConf,
  roninGovernanceAdminConf,
  maintenanceConf,
  roninTrustedOrganizationConf,
  roninValidatorSetConf,
  slashIndicatorConf,
  stakingConfig,
  stakingVestingConfig,
} from '../../../src/configs/config';
import {
  RoninGovernanceAdminArguments,
  MaintenanceArguments,
  Network,
  RoninTrustedOrganizationArguments,
  RoninValidatorSetArguments,
  SlashIndicatorArguments,
  StakingArguments,
  StakingVestingArguments,
} from '../../../src/utils';
import {
  BridgeManagerArguments,
  BridgeRewardArguments,
  bridgeManagerConf,
  bridgeRewardConf,
} from '../../../src/configs/bridge-manager';

export interface InitTestOutput {
  roninGovernanceAdminAddress: Address;
  maintenanceContractAddress: Address;
  roninTrustedOrganizationAddress: Address;
  fastFinalityTrackingAddress: Address;
  slashContractAddress: Address;
  stakingContractAddress: Address;
  stakingVestingContractAddress: Address;
  validatorContractAddress: Address;
  bridgeTrackingAddress: Address;
  bridgeSlashAddress: Address;
  bridgeRewardAddress: Address;
  roninBridgeManagerAddress: Address;
  mainchainBridgeManagerAddress: Address;
}

export interface InitTestInput {
  roninChainId?: BigNumberish;
  bridgeContract?: Address;
  startedAtBlock?: BigNumberish;
  maintenanceArguments?: MaintenanceArguments;
  stakingArguments?: StakingArguments;
  stakingVestingArguments?: StakingVestingArguments;
  slashIndicatorArguments?: SlashIndicatorArguments;
  roninValidatorSetArguments?: RoninValidatorSetArguments;
  roninTrustedOrganizationArguments?: RoninTrustedOrganizationArguments;
  governanceAdminArguments?: RoninGovernanceAdminArguments;
  bridgeManagerArguments?: BridgeManagerArguments;
  bridgeRewardArguments?: BridgeRewardArguments;
}

export const defaultTestConfig: InitTestInput = {
  bridgeContract: ethers.constants.AddressZero,
  startedAtBlock: 0,

  maintenanceArguments: {
    minMaintenanceDurationInBlock: 100,
    maxMaintenanceDurationInBlock: 1000,
    minOffsetToStartSchedule: 200,
    maxOffsetToStartSchedule: 200 * 7,
    maxSchedules: 2,
    cooldownSecsToMaintain: 86400 * 3,
  },

  stakingArguments: {
    minValidatorStakingAmount: BigNumber.from(100),
    maxCommissionRate: 100_00,
    cooldownSecsToUndelegate: 3 * 86400,
    waitingSecsToRevoke: 7 * 86400,
  },

  stakingVestingArguments: {
    blockProducerBonusPerBlock: 1_000,
    bridgeOperatorBonusPerBlock: 1_100,
    topupAmount: BigNumber.from(100_000_000_000),
    fastFinalityRewardPercent: 1_00, // 1%
  },

  slashIndicatorArguments: {
    bridgeOperatorSlashing: {
      missingVotesRatioTier1: 10_00, // 10%
      missingVotesRatioTier2: 20_00, // 20%
      jailDurationForMissingVotesRatioTier2: 28800 * 2,
      skipBridgeOperatorSlashingThreshold: 10,
    },
    bridgeVotingSlashing: {
      bridgeVotingThreshold: 28800 * 3,
      bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000),
    },
    doubleSignSlashing: {
      slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10),
      doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
      doubleSigningOffsetLimitBlock: 28800, // ~1 days
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
    emergencyExitLockedAmount: 500,
    emergencyExpiryDuration: 14 * 86400, // 14 days
  },

  roninTrustedOrganizationArguments: {
    trustedOrganizations: [],
    numerator: 0,
    denominator: 1,
  },

  governanceAdminArguments: {
    proposalExpiryDuration: 60 * 60 * 24 * 14, // 14 days
  },

  bridgeManagerArguments: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 60 * 60 * 24 * 14, // 14 days
    members: [],
  },

  bridgeRewardArguments: {
    rewardPerPeriod: 5_000,
    topupAmount: BigNumber.from(100_000_000_000),
  },
};

export const initTest = (id: string) =>
  deployments.createFixture<InitTestOutput, InitTestInput>(async ({ deployments }, options) => {
    if (network.name == Network.Hardhat) {
      generalRoninConf[network.name] = {
        ...generalRoninConf[network.name],
        roninChainId: options?.roninChainId ?? network.config.chainId,
        bridgeContract: options?.bridgeContract ?? defaultTestConfig.bridgeContract!,
        startedAtBlock: options?.startedAtBlock ?? defaultTestConfig.startedAtBlock!,
      };
      generalMainchainConf[network.name] = {
        ...generalMainchainConf[network.name],
        roninChainId: options?.roninChainId ?? network.config.chainId,
        bridgeContract: options?.bridgeContract ?? defaultTestConfig.bridgeContract!,
        startedAtBlock: options?.startedAtBlock ?? defaultTestConfig.startedAtBlock!,
      };
      maintenanceConf[network.name] = {
        ...defaultTestConfig?.maintenanceArguments,
        ...options?.maintenanceArguments,
      };
      slashIndicatorConf[network.name] = {
        bridgeOperatorSlashing: {
          ...defaultTestConfig?.slashIndicatorArguments?.bridgeOperatorSlashing,
          ...options?.slashIndicatorArguments?.bridgeOperatorSlashing,
        },
        bridgeVotingSlashing: {
          ...defaultTestConfig?.slashIndicatorArguments?.bridgeVotingSlashing,
          ...options?.slashIndicatorArguments?.bridgeVotingSlashing,
        },
        doubleSignSlashing: {
          ...defaultTestConfig?.slashIndicatorArguments?.doubleSignSlashing,
          ...options?.slashIndicatorArguments?.doubleSignSlashing,
        },
        unavailabilitySlashing: {
          ...defaultTestConfig?.slashIndicatorArguments?.unavailabilitySlashing,
          ...options?.slashIndicatorArguments?.unavailabilitySlashing,
        },
        creditScore: {
          ...defaultTestConfig?.slashIndicatorArguments?.creditScore,
          ...options?.slashIndicatorArguments?.creditScore,
        },
      };
      roninValidatorSetConf[network.name] = {
        ...defaultTestConfig?.roninValidatorSetArguments,
        ...options?.roninValidatorSetArguments,
      };
      stakingConfig[network.name] = {
        ...defaultTestConfig?.stakingArguments,
        ...options?.stakingArguments,
      };
      stakingVestingConfig[network.name] = {
        ...defaultTestConfig?.stakingVestingArguments,
        ...options?.stakingVestingArguments,
      };
      roninTrustedOrganizationConf[network.name] = {
        ...defaultTestConfig?.roninTrustedOrganizationArguments,
        ...options?.roninTrustedOrganizationArguments,
      };
      roninGovernanceAdminConf[network.name] = {
        ...defaultTestConfig?.governanceAdminArguments,
        ...options?.governanceAdminArguments,
      };
      bridgeManagerConf[network.name] = {
        ...defaultTestConfig?.bridgeManagerArguments,
        ...options?.bridgeManagerArguments,
      };
      bridgeRewardConf[network.name] = {
        ...defaultTestConfig?.bridgeRewardArguments,
        ...options?.bridgeRewardArguments,
      };
    }

    await deployments.fixture([
      '_HelperDposCalculate',
      'RoninGovernanceAdmin',
      'FastFinalityTrackingProxy',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'MaintenanceProxy',
      'StakingVestingProxy',
      id,
    ]);

    const roninGovernanceAdminDeployment = await deployments.get('RoninGovernanceAdmin');
    const fastFinalityTrackingContractDeployment = await deployments.get('FastFinalityTrackingProxy');
    const maintenanceContractDeployment = await deployments.get('MaintenanceProxy');
    const roninTrustedOrganizationDeployment = await deployments.get('RoninTrustedOrganizationProxy');
    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    const stakingContractDeployment = await deployments.get('StakingProxy');
    const stakingVestingContractDeployment = await deployments.get('StakingVestingProxy');
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');

    await deployments.fixture([
      '_HelperBridgeCalculate',
      'BridgeTrackingProxy',
      'RoninBridgeManager',
      'MainchainBridgeManager',
      id,
    ]);
    const bridgeTrackingDeployment = await deployments.get('BridgeTrackingProxy');
    const bridgeSlashDeployment = await deployments.get('BridgeSlashProxy');
    const bridgeRewardDeployment = await deployments.get('BridgeRewardProxy');
    const roninBridgeManagerDeployment = await deployments.get('RoninBridgeManager');
    const mainchainBridgeManagerDeployment = await deployments.get('MainchainBridgeManager');

    await EpochController.setTimestampToPeriodEnding();

    return {
      roninGovernanceAdminAddress: roninGovernanceAdminDeployment.address,
      maintenanceContractAddress: maintenanceContractDeployment.address,
      fastFinalityTrackingAddress: fastFinalityTrackingContractDeployment.address,
      roninTrustedOrganizationAddress: roninTrustedOrganizationDeployment.address,
      slashContractAddress: slashContractDeployment.address,
      stakingContractAddress: stakingContractDeployment.address,
      stakingVestingContractAddress: stakingVestingContractDeployment.address,
      validatorContractAddress: validatorContractDeployment.address,
      bridgeTrackingAddress: bridgeTrackingDeployment.address,
      bridgeSlashAddress: bridgeSlashDeployment.address,
      bridgeRewardAddress: bridgeRewardDeployment.address,
      roninBridgeManagerAddress: roninBridgeManagerDeployment.address,
      mainchainBridgeManagerAddress: mainchainBridgeManagerDeployment.address,
    };
  }, id);
