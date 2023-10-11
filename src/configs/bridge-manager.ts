import { BigNumber, BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../utils';
import { Address } from 'hardhat-deploy/dist/types';
import { TargetOption } from '../script/proposal';

export type BridgeManagerMemberStruct = {
  governor: Address;
  operator: Address;
  weight: BigNumberish;
};

export type TargetOptionStruct = {
  option: TargetOption;
  target: Address;
};

export interface BridgeManagerArguments {
  numerator?: BigNumberish;
  denominator?: BigNumberish;
  expiryDuration?: BigNumberish;
  members?: BridgeManagerMemberStruct[];
  targets?: TargetOptionStruct[];
}

export interface BridgeManagerConfig {
  [network: LiteralNetwork]: undefined | BridgeManagerArguments;
}

export const bridgeManagerConf: BridgeManagerConfig = {
  [Network.Hardhat]: undefined,
  [Network.Goerli]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa',
        operator: '0x2e82D2b56f858f79DeeF11B160bFC4631873da2B',
        weight: 100,
      },
      {
        governor: '0xb033ba62EC622dC54D0ABFE0254e79692147CA26',
        operator: '0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb',
        weight: 100,
      },
      {
        governor: '0x087D08e3ba42e64E3948962dd1371F906D1278b9',
        operator: '0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c',
        weight: 100,
      },
      {
        governor: '0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F',
        operator: '0xcc5fc5b6c8595f56306da736f6cd02ed9141c84a',
        weight: 100,
      },
    ],
  },
  [Network.Testnet]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa',
        operator: '0x2e82D2b56f858f79DeeF11B160bFC4631873da2B',
        weight: 100,
      },
      {
        governor: '0xb033ba62EC622dC54D0ABFE0254e79692147CA26',
        operator: '0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb',
        weight: 100,
      },
      {
        governor: '0x087D08e3ba42e64E3948962dd1371F906D1278b9',
        operator: '0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c',
        weight: 100,
      },
      {
        governor: '0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F',
        operator: '0xcc5fc5b6c8595f56306da736f6cd02ed9141c84a',
        weight: 100,
      },
    ],
  },
  [Network.Mainnet]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0x3200A8eb56767c3760e108Aa27C65bfFF036d8E6', // Bao's temp address
        operator: '0x32015E8B982c61bc8a593816FdBf03A603EEC823', // Bao's temp address
        weight: 100,
      },
    ],
  },
  [Network.Ethereum]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0x3200A8eb56767c3760e108Aa27C65bfFF036d8E6', // Bao's temp address
        operator: '0x32015E8B982c61bc8a593816FdBf03A603EEC823', // Bao's temp address
        weight: 100,
      },
    ],
  },
};

export interface BridgeRewardArguments {
  rewardPerPeriod?: BigNumberish;
  topupAmount?: BigNumberish;
}
export interface BridgeRewardConfig {
  [network: LiteralNetwork]: BridgeRewardArguments | undefined;
}

const defaultBridgeRewardConf: BridgeRewardArguments = {
  rewardPerPeriod: BigNumber.from(10).pow(18), // 1 RON per block
};

export const bridgeRewardConf: BridgeRewardConfig = {
  [Network.Hardhat]: undefined,
  [Network.Local]: defaultBridgeRewardConf,
  [Network.Devnet]: defaultBridgeRewardConf,
  [Network.Testnet]: {
    rewardPerPeriod: BigNumber.from(10).pow(18), // 1 RON per period,
    topupAmount: BigNumber.from(10).pow(18).mul(1_000_000), // 1M RON
  },
  [Network.Mainnet]: {
    rewardPerPeriod: BigNumber.from('2739726027397260273972'), // (1M/365) ~ 2739.7260 RON per period,
    topupAmount: 0,
  },
};
