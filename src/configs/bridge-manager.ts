import { BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../utils';

export interface BridgeManagerArguments {
  numerator?: BigNumberish;
  denominator?: BigNumberish;
  expiryDuration?: BigNumberish;
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
