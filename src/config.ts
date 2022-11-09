import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  GeneralConfig,
  LiteralNetwork,
  MainchainGovernanceAdminConfig,
  MaintenanceConfig,
  Network,
  RoninTrustedOrganizationConfig,
  RoninValidatorSetConfig,
  SlashIndicatorConfig,
  StakingConfig,
  StakingVestingConfig,
} from './utils';

export const commonNetworks: LiteralNetwork[] = [Network.Hardhat, Network.Devnet];
export const mainchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Goerli, Network.Ethereum];
export const roninchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Testnet, Network.Mainnet];
export const allNetworks: LiteralNetwork[] = [
  ...commonNetworks,
  ...mainchainNetworks.slice(commonNetworks.length),
  ...roninchainNetworks.slice(commonNetworks.length),
];

export const defaultAddress = '0x0000000000000000000000000000000000000000';

export const generalRoninConf: GeneralConfig = {
  [Network.Hardhat]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
  [Network.Devnet]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
  [Network.Testnet]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
};

export const generalMainchainConf: GeneralConfig = {
  [Network.Hardhat]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
  [Network.Devnet]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
  [Network.Testnet]: {
    startedAtBlock: 0,
    bridgeContract: ethers.constants.AddressZero,
  },
};

// TODO: update config for testnet & mainnet
export const maintenanceConf: MaintenanceConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    minMaintenanceBlockPeriod: 600, // 600 blocks
    maxMaintenanceBlockPeriod: 28800, // ~1 day
    minOffset: 28800, // requests before maintaining at least ~1 day
    maxSchedules: 3, // only 3 schedules are happening|in the futures
  },
  [Network.Testnet]: {
    minMaintenanceBlockPeriod: 600, // 600 blocks
    maxMaintenanceBlockPeriod: 28800, // ~1 day
    minOffset: 28800, // requests before maintaining at least ~1 day
    maxSchedules: 3, // only 3 schedules are happening|in the futures
  },
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const stakingConfig: StakingConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
    cooldownSecsToUndelegate: 3 * 86400, // at least 3 days
    waitingSecsToRevoke: 7 * 86400, // at least 7 days
  },
  [Network.Testnet]: {
    minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5).mul(5)), // 500.000 RON
    cooldownSecsToUndelegate: 3 * 86400, // at least 3 days
    waitingSecsToRevoke: 7 * 86400, // at least 7 days
  },
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const stakingVestingConfig: StakingVestingConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    blockProducerBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    bridgeOperatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(4)), // 10.000 RON
  },
  [Network.Testnet]: {
    blockProducerBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    bridgeOperatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  },
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const slashIndicatorConf: SlashIndicatorConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
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
  },
  [Network.Testnet]: {
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
      slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5).mul(5)), // 500.000 RON
      doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
    },
    unavailabilitySlashing: {
      unavailabilityTier1Threshold: 50,
      unavailabilityTier2Threshold: 150,
      slashAmountForUnavailabilityTier2Threshold: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(4)), // 10.000 RON
      jailDurationForUnavailabilityTier2Threshold: 2 * 28800, // jails for 2 days
    },
    creditScore: {
      gainCreditScore: 50,
      maxCreditScore: 600,
      bailOutCostMultiplier: 5,
      cutOffPercentageAfterBailout: 50_00, // 50%
    },
  },
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const roninValidatorSetConf: RoninValidatorSetConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    maxValidatorNumber: 21,
    maxPrioritizedValidatorNumber: 11,
    maxValidatorCandidate: 100,
    numberOfBlocksInEpoch: 600,
  },
  [Network.Testnet]: {
    maxValidatorNumber: 21,
    maxPrioritizedValidatorNumber: 11,
    maxValidatorCandidate: 100,
    numberOfBlocksInEpoch: 200,
  },
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet, mainnet, goerli, ethereum
export const roninTrustedOrganizationConf: RoninTrustedOrganizationConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    trustedOrganizations: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'].map((addr) => ({
      consensusAddr: addr,
      governor: addr,
      bridgeVoter: addr,
      weight: 100,
      addedBlock: 0,
    })),
    numerator: 0,
    denominator: 1,
  },
  [Network.Testnet]: {
    trustedOrganizations: [].map((addr) => ({
      // TODO: @minh-bq
      consensusAddr: addr,
      governor: addr,
      bridgeVoter: addr,
      weight: 100,
      addedBlock: 0,
    })),
    numerator: 9,
    denominator: 11,
  },
  [Network.Mainnet]: undefined,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};

// TODO: update config for goerli, ethereum
export const mainchainGovernanceAdminConf: MainchainGovernanceAdminConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    roleSetter: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
    relayers: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'],
  },
  [Network.Goerli]: {
    roleSetter: '', // TODO
    relayers: [''], // TODO,
  },
  [Network.Ethereum]: undefined,
};
