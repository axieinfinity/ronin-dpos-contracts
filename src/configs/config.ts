import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  GeneralConfig,
  RoninGovernanceAdminArguments,
  RoninGovernanceAdminConfig,
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
  VaultForwarderConfig,
} from '../utils';
import { trustedOrgSet } from './addresses';

export const commonNetworks: LiteralNetwork[] = [Network.Local, Network.Hardhat, Network.Devnet];
export const mainchainNetworks: LiteralNetwork[] = [
  ...commonNetworks,
  Network.Goerli,
  Network.GoerliForDevnet,
  Network.Ethereum,
];
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
  [Network.Devnet]: {
    roninChainId: 2022,
    startedAtBlock: 11710199,
    bridgeContract: '0xCee681C9108c42C710c6A8A949307D5F13C9F3ca',
  },
  [Network.Testnet]: {
    roninChainId: 2021,
    startedAtBlock: 11710199,
    bridgeContract: '0xCee681C9108c42C710c6A8A949307D5F13C9F3ca',
  },
  [Network.Mainnet]: {
    roninChainId: 2020,
    startedAtBlock: 23155200,
    bridgeContract: '0x0cf8ff40a508bdbc39fbe1bb679dcba64e65c7df', // https://explorer.roninchain.com/address/ronin:0cf8ff40a508bdbc39fbe1bb679dcba64e65c7df
  },
};

export const generalMainchainConf: GeneralConfig = {
  [Network.Local]: defaultGeneralConf,
  [Network.Hardhat]: defaultGeneralConf,
  [Network.Goerli]: {
    roninChainId: 2021,
    startedAtBlock: 0,
    bridgeContract: '0x9e359F42cDDc84A386a2Ef1D9Ae06623f3970D1D',
  },
  [Network.GoerliForDevnet]: {
    ...defaultGeneralConf,
    roninChainId: 2022,
  },
  [Network.Ethereum]: {
    roninChainId: 2020,
    bridgeContract: '0x64192819ac13ef72bf6b5ae239ac672b43a9af08', // https://etherscan.io/address/0x64192819ac13ef72bf6b5ae239ac672b43a9af08
  },
};

const defaultMaintenanceConf: MaintenanceArguments = {
  minMaintenanceDurationInBlock: 600, // 600 blocks
  maxMaintenanceDurationInBlock: 28800, // ~1 day
  minOffsetToStartSchedule: 28800, // requests before maintaining at least ~1 day
  maxOffsetToStartSchedule: 28800 * 7, // requests before maintaining at most ~7 day
  maxSchedules: 3, // only 3 schedules are happening|in the futures
  cooldownSecsToMaintain: 86400 * 3, // request next maintenance must wait at least 3 days.
};

export const maintenanceConf: MaintenanceConfig = {
  [Network.Local]: defaultMaintenanceConf,
  [Network.Devnet]: defaultMaintenanceConf,
  [Network.Testnet]: {
    ...defaultMaintenanceConf,
    minMaintenanceDurationInBlock: 200,
  },
  [Network.Mainnet]: {
    ...defaultMaintenanceConf,
    minOffsetToStartSchedule: 1000,
  },
};

const defaultStakingConf: StakingArguments = {
  minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  maxCommissionRate: 20_00, // 20%
  cooldownSecsToUndelegate: 3 * 86400, // at least 3 days
  waitingSecsToRevoke: 7 * 86400, // at least 7 days
};

export const stakingConfig: StakingConfig = {
  [Network.Local]: defaultStakingConf,
  [Network.Devnet]: defaultStakingConf,
  [Network.Testnet]: {
    ...defaultStakingConf,
    minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5).mul(5)), // 500.000 RON
  },
  [Network.Mainnet]: {
    ...defaultStakingConf,
    minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(250_000), // 250.000 RON
  },
};

const defaultStakingVestingConf: StakingVestingArguments = {
  blockProducerBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
  bridgeOperatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
  topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(4)), // 10.000 RON
};

export const stakingVestingConfig: StakingVestingConfig = {
  [Network.Local]: defaultStakingVestingConf,
  [Network.Devnet]: defaultStakingVestingConf,
  [Network.Testnet]: {
    ...defaultStakingVestingConf,
    topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
    fastFinalityRewardPercent: 50, // 0.5%
  },
  [Network.Mainnet]: {
    ...defaultStakingVestingConf,
    blockProducerBonusPerBlock: BigNumber.from('2853881278540000000'), // 2.85388127854 RON per block
    bridgeOperatorBonusPerBlock: BigNumber.from('95129375950000000'), // 0.09512937595 RON per block
    topupAmount: 0,
    fastFinalityRewardPercent: 50, // 0.5%
  },
};

const defaultSlashIndicatorConf: SlashIndicatorArguments = {
  bridgeOperatorSlashing: {
    missingVotesRatioTier1: 10_00, // 10%
    missingVotesRatioTier2: 20_00, // 20%
    jailDurationForMissingVotesRatioTier2: 28800 * 2, // jails for 2 days
    skipBridgeOperatorSlashingThreshold: 50,
  },
  bridgeVotingSlashing: {
    bridgeVotingThreshold: 28800 * 3, // ~3 days
    bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000), // 10.000 RON
  },
  doubleSignSlashing: {
    slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
    doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
    doubleSigningOffsetLimitBlock: 28800 * 7, // ~7 days
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

export const slashIndicatorConf: SlashIndicatorConfig = {
  [Network.Local]: defaultSlashIndicatorConf,
  [Network.Devnet]: defaultSlashIndicatorConf,
  [Network.Testnet]: {
    ...defaultSlashIndicatorConf,
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
  },
  [Network.Mainnet]: {
    bridgeOperatorSlashing: {
      missingVotesRatioTier1: 10_00, // 10%
      missingVotesRatioTier2: 30_00, // 30%
      jailDurationForMissingVotesRatioTier2: 28800 * 2, // jails for 2 days
      skipBridgeOperatorSlashingThreshold: 50,
    },
    bridgeVotingSlashing: {
      bridgeVotingThreshold: 28800 * 3, // ~3 days
      bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000), // 10.000 RON
    },
    doubleSignSlashing: {
      slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(250_000), // 250.000 RON
      doubleSigningJailUntilBlock: ethers.constants.MaxUint256,
      doubleSigningOffsetLimitBlock: 28800 * 7, // ~7 days
    },
    unavailabilitySlashing: {
      unavailabilityTier1Threshold: 50,
      unavailabilityTier2Threshold: 150,
      slashAmountForUnavailabilityTier2Threshold: BigNumber.from(10).pow(18).mul(10_000), // 10.000 RON
      jailDurationForUnavailabilityTier2Threshold: 2 * 28800, // jails for 2 days
    },
    creditScore: {
      gainCreditScore: 50,
      maxCreditScore: 600,
      bailOutCostMultiplier: 2,
      cutOffPercentageAfterBailout: 50_00, // 50%
    },
  },
};

const defaultRoninValidatorSetConf: RoninValidatorSetArguments = {
  maxValidatorNumber: 21,
  maxPrioritizedValidatorNumber: 11,
  maxValidatorCandidate: 100,
  numberOfBlocksInEpoch: 600,
  minEffectiveDaysOnwards: 7,
  emergencyExitLockedAmount: BigNumber.from(10).pow(18).mul(50_000), // 50.000 RON
  emergencyExpiryDuration: 14 * 86400, // 14 days
};

export const roninValidatorSetConf: RoninValidatorSetConfig = {
  [Network.Local]: defaultRoninValidatorSetConf,
  [Network.Devnet]: defaultRoninValidatorSetConf,
  [Network.Testnet]: {
    maxValidatorNumber: 42,
    maxPrioritizedValidatorNumber: 22,
    maxValidatorCandidate: 100,
    numberOfBlocksInEpoch: 200,
    minEffectiveDaysOnwards: 7,
  },
  [Network.Mainnet]: {
    maxValidatorNumber: 22,
    maxPrioritizedValidatorNumber: 12,
    maxValidatorCandidate: 50,
    numberOfBlocksInEpoch: 200,
    minEffectiveDaysOnwards: 7,
    emergencyExitLockedAmount: BigNumber.from(10).pow(18).mul(50_000), // 50.000 RON
    emergencyExpiryDuration: 14 * 86400, // 14 days
  },
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

export const roninTrustedOrganizationConf: RoninTrustedOrganizationConfig = {
  [Network.Local]: defaultRoninTrustedOrganizationConf,
  [Network.Devnet]: defaultRoninTrustedOrganizationConf,
  [Network.Testnet]: {
    trustedOrganizations: trustedOrgSet[Network.Testnet],
    numerator: 9,
    denominator: 11,
  },
  [Network.Goerli]: {
    trustedOrganizations: trustedOrgSet[Network.Goerli],
    numerator: 9,
    denominator: 11,
  },
  [Network.GoerliForDevnet]: {
    trustedOrganizations: trustedOrgSet[Network.GoerliForDevnet],
    numerator: 9,
    denominator: 11,
  },
  [Network.Mainnet]: {
    trustedOrganizations: trustedOrgSet[Network.Mainnet],
    numerator: 9,
    denominator: 12,
  },
  [Network.Ethereum]: {
    trustedOrganizations: trustedOrgSet[Network.Ethereum],
    numerator: 9,
    denominator: 12,
  },
};

const defaultMainchainGovernanceAdminConf: MainchainGovernanceAdminArguments = {
  roleSetter: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
  relayers: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'],
};

export const mainchainGovernanceAdminConf: MainchainGovernanceAdminConfig = {
  [Network.Local]: defaultMainchainGovernanceAdminConf,
  [Network.Devnet]: defaultMainchainGovernanceAdminConf,
  [Network.Goerli]: {
    roleSetter: '0xC37b5d7891D73F2064B0eE044844e053872Ef941',
    relayers: ['0xC37b5d7891D73F2064B0eE044844e053872Ef941'],
  },
  [Network.GoerliForDevnet]: {
    roleSetter: '0xC37b5d7891D73F2064B0eE044844e053872Ef941',
    relayers: ['0xC37b5d7891D73F2064B0eE044844e053872Ef941'],
  },
  [Network.Ethereum]: {
    roleSetter: '0x2DA02aC5f19Ae362a4121718d990e655eB628D96', // https://etherscan.io/address/0x2DA02aC5f19Ae362a4121718d990e655eB628D96
    relayers: [
      '0xbb772579dfe08f7c7c73daca0a414fca4c9e57ac',
      '0xE5EB222996967BE79468C28bA39D665fd96E8b30',
      '0x77Ab649Caa7B4b673C9f2cF069900DF48114d79D',
      '0xaaBD1f9bA401F4C56F7717c71C4fD9369Dacf7cE',
      '0x1FE5F98A40602Fc002d57EA803C2d6951649d637',
      '0x60c4b72fc62b3e3a74e283aa9ba20d61dd4d8f1b',
      '0xD5877c63744903a459CCBa94c909CDaAE90575f8',
      '0xD1cF86f5D3fB220730D8d9F06C940EFA8683a2af',
      '0x02201f9bfd2face1b9f9d30d776e77382213da1a',
      '0x58aBcBCAb52dEE942491700CD0DB67826BBAA8C6',
    ], // Combined from DPoS Trusted Org and Master sheet
  },
};

const defaultGovernanceAdminConf: RoninGovernanceAdminArguments = {
  proposalExpiryDuration: 60 * 60 * 24 * 14, // 14 days
};

// TODO: update config for goerli
export const roninGovernanceAdminConf: RoninGovernanceAdminConfig = {
  [Network.Local]: defaultGovernanceAdminConf,
  [Network.Devnet]: defaultGovernanceAdminConf,
  [Network.Goerli]: undefined,
  [Network.Mainnet]: defaultGovernanceAdminConf,
};

export const vaultForwarderConf: VaultForwarderConfig = {
  [Network.Testnet]: [
    {
      vaultId: 'qc-test',
      targets: [
        '0x8a320aFb578BEed1A5BB08823CF9A5f60Ea694f4', // RoninGovernanceAdmin
        '0x7f46c5DD5f13FF0dd973317411d70800db248e7d', // RoninTrustedOrganizationProxy
        '0x4016C80D97DDCbe4286140446759a3f0c1d20584', // MaintenanceProxy
        '0xF7837778b6E180Df6696C8Fa986d62f8b6186752', // SlashIndicatorProxy
        '0x9C245671791834daf3885533D24dce516B763B28', // StakingProxy
        '0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d', // RoninValidatorSetProxy
        '0x61626ba084aDdc5dBFCdFfA257e66F8618d3feAB', // BridgeTrackingProxy
      ],
      moderator: '0x8643c5d7048d149297229ded82fd7ac1ec099999',
    },
  ],
};
