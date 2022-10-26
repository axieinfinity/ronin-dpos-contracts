import { BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { TrustedOrganizationStruct } from './types/IRoninTrustedOrganization';

export enum Network {
  Hardhat = 'hardhat',
  Devnet = 'ronin-devnet',
  Testnet = 'ronin-testnet',
  Mainnet = 'ronin-mainnet',
  Goerli = 'goerli',
  Ethereum = 'ethereum',
}

export type LiteralNetwork = Network | string;

export const commonNetworks: LiteralNetwork[] = [Network.Hardhat, Network.Devnet];
export const mainchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Goerli, Network.Ethereum];
export const roninchainNetworks: LiteralNetwork[] = [...commonNetworks, Network.Testnet, Network.Mainnet];
export const allNetworks: LiteralNetwork[] = [
  ...commonNetworks,
  ...mainchainNetworks.slice(commonNetworks.length),
  ...roninchainNetworks.slice(commonNetworks.length),
];

export const defaultAddress = '0x0000000000000000000000000000000000000000';

export interface AddressExtended {
  address: Address;
  nonce?: number;
}

export interface InitAddr {
  [network: LiteralNetwork]: {
    governanceAdmin?: AddressExtended;
    maintenanceContract?: AddressExtended;
    stakingVestingContract?: AddressExtended;
    slashIndicatorContract?: AddressExtended;
    stakingContract?: AddressExtended;
    validatorContract?: AddressExtended;
    roninTrustedOrganizationContract?: AddressExtended;
  };
}

export interface MaintenanceArguments {
  minMaintenanceBlockPeriod?: BigNumberish;
  maxMaintenanceBlockPeriod?: BigNumberish;
  minOffset?: BigNumberish;
  maxSchedules?: BigNumberish;
}

export interface RoninTrustedOrganizationArguments {
  trustedOrganizations?: TrustedOrganizationStruct[];
  numerator?: BigNumberish;
  denominator?: BigNumberish;
}

export interface RoninTrustedOrganizationConfig {
  [network: LiteralNetwork]: RoninTrustedOrganizationArguments | undefined;
}

export interface MaintenanceConfig {
  [network: LiteralNetwork]: MaintenanceArguments | undefined;
}

export interface StakingArguments {
  minValidatorBalance?: BigNumberish;
}

export interface StakingConfig {
  [network: LiteralNetwork]: StakingArguments | undefined;
}

export interface StakingVestingArguments {
  validatorBonusPerBlock?: BigNumberish;
  bridgeOperatorBonusPerBlock?: BigNumberish;
  topupAmount?: BigNumberish;
}

export interface StakingVestingConfig {
  [network: LiteralNetwork]: StakingVestingArguments | undefined;
}

export interface SlashIndicatorArguments {
  misdemeanorThreshold?: BigNumberish;
  felonyThreshold?: BigNumberish;
  bridgeVotingThreshold?: BigNumberish;
  slashFelonyAmount?: BigNumberish;
  slashDoubleSignAmount?: BigNumberish;
  bridgeVotingSlashAmount?: BigNumberish;
  felonyJailBlocks?: BigNumberish;
  doubleSigningConstrainBlocks?: BigNumberish;
  gainCreditScore?: BigNumberish;
  maxCreditScore?: BigNumberish;
  bailOutCostMultiplier?: BigNumberish;
}

export interface SlashIndicatorConfig {
  [network: LiteralNetwork]: SlashIndicatorArguments | undefined;
}

export interface RoninValidatorSetArguments {
  maxValidatorNumber?: BigNumberish;
  maxValidatorCandidate?: BigNumberish;
  maxPrioritizedValidatorNumber?: BigNumberish;
  numberOfBlocksInEpoch?: BigNumberish;
}

export interface RoninValidatorSetConfig {
  [network: LiteralNetwork]: RoninValidatorSetArguments | undefined;
}

export interface RoninGovernanceAdminArguments {
  bridgeContract?: Address;
}

export interface RoninGovernanceAdminConfig {
  [network: LiteralNetwork]: RoninGovernanceAdminArguments | undefined;
}

export type MainchainGovernanceAdminArguments = RoninGovernanceAdminArguments & {
  roleSetter?: Address;
  relayers?: Address[];
};

export interface MainchainGovernanceAdminConfig {
  [network: LiteralNetwork]: MainchainGovernanceAdminArguments | undefined;
}

export const roninInitAddress: InitAddr = {};
export const mainchainInitAddress: InitAddr = {};

// TODO: update config for testnet & mainnet
export const maintenanceConf: MaintenanceConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    minMaintenanceBlockPeriod: 600, // 600 blocks
    maxMaintenanceBlockPeriod: 28800, // ~1 day
    minOffset: 28800, // requests before maintaining at least ~1 day
    maxSchedules: 3, // only 3 schedules are happening|in the futures
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const stakingConfig: StakingConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    minValidatorBalance: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(5)), // 100.000 RON
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const stakingVestingConfig: StakingVestingConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    validatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    bridgeOperatorBonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
    topupAmount: BigNumber.from(10).pow(18).mul(BigNumber.from(10).pow(4)), // 10.000 RON
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const slashIndicatorConf: SlashIndicatorConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    misdemeanorThreshold: 50,
    felonyThreshold: 150,
    bridgeVotingThreshold: 28800 * 3, // ~3 days
    slashFelonyAmount: BigNumber.from(10).pow(18).mul(1), // 1 RON
    slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
    bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000), // 10.000 RON
    felonyJailBlocks: 28800 * 2, // jails for 2 days
    doubleSigningConstrainBlocks: 28800,
  },
  [Network.Testnet]: undefined,
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
  [Network.Testnet]: undefined,
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
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};

// TODO: update config for testnet & mainnet
export const roninGovernanceAdminConf: RoninGovernanceAdminConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    bridgeContract: ethers.constants.AddressZero,
  },
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};

// TODO: update config for goerli, ethereum
export const mainchainGovernanceAdminConf: MainchainGovernanceAdminConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    roleSetter: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
    bridgeContract: ethers.constants.AddressZero,
    relayers: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'],
  },
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};
