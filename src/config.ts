import { BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';

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
    governanceAdmin: Address;
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
  trustedOrganization?: Address[];
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
  bonusPerBlock?: BigNumberish;
  topupAmount?: BigNumberish;
}

export interface StakingVestingConfig {
  [network: LiteralNetwork]: StakingVestingArguments | undefined;
}

export interface SlashIndicatorArguments {
  misdemeanorThreshold?: BigNumberish;
  felonyThreshold?: BigNumberish;
  slashFelonyAmount?: BigNumberish;
  slashDoubleSignAmount?: BigNumberish;
  felonyJailBlocks?: BigNumberish;
  doubleSigningConstrainBlocks?: BigNumberish;
}

export interface SlashIndicatorConfig {
  [network: LiteralNetwork]: SlashIndicatorArguments | undefined;
}

export interface RoninValidatorSetArguments {
  maxValidatorNumber?: BigNumberish;
  maxValidatorCandidate?: BigNumberish;
  maxPrioritizedValidatorNumber?: BigNumberish;
  numberOfBlocksInEpoch?: BigNumberish;
  numberOfEpochsInPeriod?: BigNumberish;
}

export interface RoninValidatorSetConfig {
  [network: LiteralNetwork]: RoninValidatorSetArguments | undefined;
}

export const initAddress: InitAddr = {
  [Network.Hardhat]: {
    governanceAdmin: ethers.constants.AddressZero,
  },
  [Network.Devnet]: {
    governanceAdmin: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
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
    bonusPerBlock: BigNumber.from(10).pow(18), // 1 RON per block
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
    slashFelonyAmount: BigNumber.from(10).pow(18).mul(1), // 1 RON
    slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
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
    numberOfEpochsInPeriod: 48, // 1 day
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet, mainnet, goerli, ethereum
export const roninTrustedOrganizationConf: RoninTrustedOrganizationConfig = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    trustedOrganization: [], // trusted no one
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
  [Network.Goerli]: undefined,
  [Network.Ethereum]: undefined,
};
