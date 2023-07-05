import { BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../utils';
import { Threshold } from './gateway';

interface MainchainManagerConfig {
  expiryDuration?: BigNumberish;
}

interface BridgeManagerConfig {
  [network: LiteralNetwork]: undefined | (Threshold & MainchainManagerConfig);
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
