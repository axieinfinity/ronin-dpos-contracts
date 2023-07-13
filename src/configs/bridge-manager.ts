import { BigNumber, BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../utils';
import { Address } from 'hardhat-deploy/dist/types';

export interface BridgeManagerArguments {
  numerator?: BigNumberish;
  denominator?: BigNumberish;
  expiryDuration?: BigNumberish;
  weights?: BigNumberish[];
  operators?: Address[];
  governors?: Address[];
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
  },
  [Network.Testnet]: {
    numerator: 70,
    denominator: 100,
  },
};

export interface BridgeRewardArguments {
  rewardPerPeriod?: BigNumberish;
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
};
