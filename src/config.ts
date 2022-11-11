import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  GeneralConfig,
  LiteralNetwork,
  MainchainGovernanceAdminArguments,
  MainchainGovernanceAdminConfig,
  MaintenanceArguments,
  MaintenanceConfig,
  Network,
  RoninTrustedOrganizationArguments,
  RoninTrustedOrganizationConfig,
  RoninValidatorSetArguments,
  RoninValidatorSetConfig,
  SlashIndicatorArguments,
  SlashIndicatorConfig,
  StakingArguments,
  StakingConfig,
  StakingVestingArguments,
  StakingVestingConfig,
} from './utils';

export const commonNetworks: LiteralNetwork[] = [Network.Local, Network.Hardhat, Network.Devnet];
export const mainchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Goerli, Network.Ethereum];
export const roninchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Testnet, Network.Mainnet];
export const allNetworks: LiteralNetwork[] = [
  ...commonNetworks,
  ...mainchainNetworks.slice(commonNetworks.length),
  ...roninchainNetworks.slice(commonNetworks.length),
];

export const defaultAddress = '0x0000000000000000000000000000000000000000';

const defaultGeneralConf = {
  startedAtBlock: 0,
  bridgeContract: ethers.constants.AddressZero,
};

export const generalRoninConf: GeneralConfig = {
  [Network.Local]: defaultGeneralConf,
  [Network.Hardhat]: defaultGeneralConf,
  [Network.Devnet]: defaultGeneralConf,
};

export const generalMainchainConf: GeneralConfig = {
  [Network.Local]: defaultGeneralConf,
  [Network.Hardhat]: defaultGeneralConf,
  [Network.Devnet]: defaultGeneralConf,
};

const defaultMaintenanceConf: MaintenanceArguments = {
  minMaintenanceDurationInBlock: 600, // 600 blocks
  maxMaintenanceDurationInBlock: 28800, // ~1 day
  minOffsetToStartSchedule: 28800, // requests before maintaining at least ~1 day
  maxSchedules: 3, // only 3 schedules are happening|in the futures
};

// TODO: update config for testnet & mainnet
export const maintenanceConf: MaintenanceConfig = {
  [Network.Local]: defaultMaintenanceConf,
  [Network.Devnet]: defaultMaintenanceConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

const defaultStakingConf: StakingArguments = {
  minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  cooldownSecsToUndelegate: 3 * 86400, // at least 3 days
  waitingSecsToRevoke: 7 * 86400, // at least 7 days
};

// TODO: update config for testnet & mainnet
export const stakingConfig: StakingConfig = {
  [Network.Local]: defaultStakingConf,
  [Network.Devnet]: defaultStakingConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

const defaultStakingVestingConf: StakingVestingArguments = {
  blockProducerBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
  bridgeOperatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
  topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(4)), // 10.000 RON
};

// TODO: update config for testnet & mainnet
export const stakingVestingConfig: StakingVestingConfig = {
  [Network.Local]: defaultStakingVestingConf,
  [Network.Devnet]: defaultStakingVestingConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

const defaultSlashIndicatorConf: SlashIndicatorArguments = {
  bridgeOperatorSlashing: {
    missingVotesRatioTier1: 10_00, // 10%
    missingVotesRatioTier2: 20_00, // 20%
    jailDurationForMissingVotesRatioTier2: 28800 * 2, // jails for 2 days
  },
  bridgeVotingSlashing: {
    bridgeVotingThreshold: 28800 * 3, // ~3 days
    bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000), // 10.000 RON
  },
  doubleSignSlashing: {
    slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
    doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
  },
  unavailabilitySlashing: {
    unavailabilityTier1Threshold: 50,
    unavailabilityTier2Threshold: 150,
    slashAmountForUnavailabilityTier2Threshold: BigNumber.from(10).pow(18).mul(1), // 1 RON
    jailDurationForUnavailabilityTier2Threshold: 2 * 28800, // jails for 2 days
  },
  creditScore: {
    gainCreditScore: 50,
    maxCreditScore: 600,
    bailOutCostMultiplier: 5,
    cutOffPercentageAfterBailout: 50_00, // 50%
  },
};

// TODO: update config for testnet & mainnet
export const slashIndicatorConf: SlashIndicatorConfig = {
  [Network.Local]: defaultSlashIndicatorConf,
  [Network.Devnet]: defaultSlashIndicatorConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

const defaultRoninValidatorSetConf: RoninValidatorSetArguments = {
  maxValidatorNumber: 21,
  maxPrioritizedValidatorNumber: 11,
  maxValidatorCandidate: 100,
  numberOfBlocksInEpoch: 600,
};

// TODO: update config for testnet & mainnet
export const roninValidatorSetConf: RoninValidatorSetConfig = {
  [Network.Local]: defaultRoninValidatorSetConf,
  [Network.Devnet]: defaultRoninValidatorSetConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

const defaultRoninTrustedOrganizationConf: RoninTrustedOrganizationArguments = {
  trustedOrganizations: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'].map((addr) => ({
    consensusAddr: addr,
    governor: addr,
    bridgeVoter: addr,
    weight: 100,
    addedBlock: 0,
  })),
  numerator: 0,
  denominator: 1,
};

// TODO: update config for testnet vs. goerli, mainnet vs. ethereum
export const roninTrustedOrganizationConf: RoninTrustedOrganizationConfig = {
  [Network.Local]: defaultRoninTrustedOrganizationConf,
  [Network.Devnet]: defaultRoninTrustedOrganizationConf,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};

const defaultMainchainGovernanceAdminConf: MainchainGovernanceAdminArguments = {
  roleSetter: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
  relayers: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'],
};

// TODO: update config for goerli, ethereum
export const mainchainGovernanceAdminConf: MainchainGovernanceAdminConfig = {
  [Network.Local]: defaultMainchainGovernanceAdminConf,
  [Network.Devnet]: defaultMainchainGovernanceAdminConf,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};
