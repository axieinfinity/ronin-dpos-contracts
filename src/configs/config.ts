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
  [Network.Devnet]: defaultGeneralConf,
  [Network.Testnet]: {
    roninChainId: 2021,
    startedAtBlock: 11710199,
    bridgeContract: '0xCee681C9108c42C710c6A8A949307D5F13C9F3ca',
  },
};

export const generalMainchainConf: GeneralConfig = {
  [Network.Local]: defaultGeneralConf,
  [Network.Hardhat]: defaultGeneralConf,
  [Network.Devnet]: defaultGeneralConf,
  [Network.Goerli]: {
    roninChainId: 2021,
    startedAtBlock: 0,
    bridgeContract: '0xFc4319Ae9e6134C708b88D5Ad5Da1A4a83372502',
  },
  [Network.GoerliForDevnet]: {
    ...defaultGeneralConf,
    roninChainId: 2022,
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

// TODO: update config for testnet & mainnet
export const maintenanceConf: MaintenanceConfig = {
  [Network.Local]: defaultMaintenanceConf,
  [Network.Devnet]: defaultMaintenanceConf,
  [Network.Testnet]: {
    ...defaultMaintenanceConf,
    minMaintenanceDurationInBlock: 200,
  },
  [Network.Mainnet]: undefined,
};

const defaultStakingConf: StakingArguments = {
  minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  maxCommissionRate: 20_00, // 20%
  cooldownSecsToUndelegate: 3 * 86400, // at least 3 days
  waitingSecsToRevoke: 7 * 86400, // at least 7 days
};

// TODO: update config for testnet & mainnet
export const stakingConfig: StakingConfig = {
  [Network.Local]: defaultStakingConf,
  [Network.Devnet]: defaultStakingConf,
  [Network.Testnet]: {
    ...defaultStakingConf,
    minValidatorStakingAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5).mul(5)), // 500.000 RON
  },
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
  [Network.Testnet]: {
    ...defaultStakingVestingConf,
    topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  },
  [Network.Mainnet]: undefined,
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

// TODO: update config for testnet & mainnet
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
  [Network.Mainnet]: undefined,
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

// TODO: update config for testnet & mainnet
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
  [Network.Testnet]: {
    trustedOrganizations: [
      '0xAcf8Bf98D1632e602d0B1761771049aF21dd6597',
      '0xCaba9D9424D6bAD99CE352A943F59279B533417a',
      '0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc',
      '0xD086D2e3Fac052A3f695a4e8905Ce1722531163C',
      '0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa',
      '0x42c535deCcc071D9039b177Cb3AbF30411531b05',
      '0x9422d990AcDc3f2b3AA3B97303aD3060F09d7ffC',
      '0x877eFEfFE7A23E42C39e2C99b977e4AA4BEC7517',
      '0x95908d03bA55c2a44688330b59E746Fdb2f17E3E',
      '0x771DEc03db66a566a1DfE3fd635B3f8D404b9291',
      '0xb212F24D850a0Ed90F2889dee31870E7FF3fED6c',
    ].map((addr) => ({
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
  [Network.Goerli]: {
    trustedOrganizations: [
      '0xAcf8Bf98D1632e602d0B1761771049aF21dd6597',
      '0xCaba9D9424D6bAD99CE352A943F59279B533417a',
      '0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc',
      '0xD086D2e3Fac052A3f695a4e8905Ce1722531163C',
      '0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa',
      '0x42c535deCcc071D9039b177Cb3AbF30411531b05',
      '0x9422d990AcDc3f2b3AA3B97303aD3060F09d7ffC',
      '0x877eFEfFE7A23E42C39e2C99b977e4AA4BEC7517',
      '0x95908d03bA55c2a44688330b59E746Fdb2f17E3E',
      '0x771DEc03db66a566a1DfE3fd635B3f8D404b9291',
      '0xb212F24D850a0Ed90F2889dee31870E7FF3fED6c',
    ].map((addr) => ({
      consensusAddr: addr,
      governor: addr,
      bridgeVoter: addr,
      weight: 100,
      addedBlock: 0,
    })),
    numerator: 9,
    denominator: 11,
  },
  [Network.GoerliForDevnet]: {
    trustedOrganizations: trustedOrgSet[Network.GoerliForDevnet],
    numerator: 9,
    denominator: 11,
  },
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
  [Network.Goerli]: {
    roleSetter: '0xC37b5d7891D73F2064B0eE044844e053872Ef941',
    relayers: ['0xC37b5d7891D73F2064B0eE044844e053872Ef941'],
  },
  [Network.GoerliForDevnet]: {
    roleSetter: '0xC37b5d7891D73F2064B0eE044844e053872Ef941',
    relayers: ['0xC37b5d7891D73F2064B0eE044844e053872Ef941'],
  },
  [Network.Ethereum]: undefined,
};

const defaultGovernanceAdminConf: RoninGovernanceAdminArguments = {
  proposalExpiryDuration: 60 * 60 * 24 * 14, // 14 days
};

// TODO: update config for goerli, ethereum
export const roninGovernanceAdminConf: RoninGovernanceAdminConfig = {
  [Network.Local]: defaultGovernanceAdminConf,
  [Network.Devnet]: defaultGovernanceAdminConf,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
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
