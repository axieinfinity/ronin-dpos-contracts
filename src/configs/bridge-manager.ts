import { BigNumberish } from 'ethers';
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

export interface MainchainBridgeManagerArguments {
  roleSetter?: Address;
  relayers?: Address[];
}

export interface BridgeManagerConfig {
  [network: LiteralNetwork]: undefined | BridgeManagerArguments;
}
export interface MainchainBridgeManagerConfig {
  [network: LiteralNetwork]: MainchainBridgeManagerArguments | undefined;
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

const defaultBridgeManagerConf: MainchainBridgeManagerArguments = {
  roleSetter: '0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1',
  relayers: ['0x93b8eed0a1e082ae2f478fd7f8c14b1fc0261bb1'],
};

export const mainchainBridgeManagerConf: MainchainBridgeManagerConfig = {
  [Network.Local]: defaultBridgeManagerConf,
  [Network.Goerli]: {
    roleSetter: '0xC37b5d7891D73F2064B0eE044844e053872Ef941',
    relayers: ['0xC37b5d7891D73F2064B0eE044844e053872Ef941'],
  },
};
