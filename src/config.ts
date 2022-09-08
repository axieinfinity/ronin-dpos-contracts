import { BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';

export enum Network {
  Hardhat = 'hardhat',
  Devnet = 'ronin-devnet',
  Testnet = 'ronin-testnet',
  Mainnet = 'ronin-mainnet',
}

export type LiteralNetwork = Network | string;

export const defaultAddress = '0x0000000000000000000000000000000000000000';

export interface InitAddr {
  [network: LiteralNetwork]: {
    governanceAdmin: string;
    validatorContract?: string;
    stakingContract?: string;
    slashIndicator?: string;
  };
}

export interface StakingConf {
  [network: LiteralNetwork]:
    | {
        maxValidatorCandidate: BigNumberish;
        minValidatorBalance: BigNumberish;
      }
    | undefined;
}

export interface SlashIndicatorConf {
  [network: LiteralNetwork]:
    | {
        misdemeanorThreshold: BigNumberish;
        felonyThreshold: BigNumberish;
        slashFelonyAmount: BigNumberish;
        slashDoubleSignAmount: BigNumberish;
        felonyJailBlocks: BigNumberish;
      }
    | undefined;
}

export interface RoninValidatorSetConf {
  [network: LiteralNetwork]:
    | {
        maxValidatorNumber: BigNumberish;
        numberOfBlocksInEpoch: BigNumberish;
        numberOfEpochsInPeriod: BigNumberish;
      }
    | undefined;
}

export const initAddress: InitAddr = {
  [Network.Devnet]: {
    governanceAdmin: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
  },
};

// TODO: update config for testnet & mainnet
export const stakingConfig: StakingConf = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    minValidatorBalance: BigNumber.from(10).pow(18).mul(1000), // 1000 RON
    maxValidatorCandidate: 100,
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const slashIndicatorConf: SlashIndicatorConf = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    misdemeanorThreshold: 50,
    felonyThreshold: 150,
    slashFelonyAmount: BigNumber.from(10).pow(18).mul(1), // 10 RON
    slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
    felonyJailBlocks: 28800 * 2, // jails for 2 days
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};

// TODO: update config for testnet & mainnet
export const roninValidatorSetConf: RoninValidatorSetConf = {
  [Network.Hardhat]: undefined,
  [Network.Devnet]: {
    maxValidatorNumber: 21,
    numberOfBlocksInEpoch: 600,
    numberOfEpochsInPeriod: 48, // 1 day
  },
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};
