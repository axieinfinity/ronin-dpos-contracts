import { LiteralNetwork, Network } from '../utils';

interface NetworkMappingInterface {
  [network: LiteralNetwork]: LiteralNetwork;
}

export const networkMapping: NetworkMappingInterface = {
  [Network.Devnet]: Network.GoerliForDevnet,
  [Network.Testnet]: Network.Goerli,
  [Network.Mainnet]: Network.Ethereum,
};
