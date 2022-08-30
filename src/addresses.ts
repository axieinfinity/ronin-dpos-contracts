export enum Network {
  Hardhat = 'hardhat',
  Testnet = 'ronin-testnet',
  Mainnet = 'ronin-mainnet',
}

export type LiteralNetwork = Network | string;

export const defaultAddress = '0x0000000000000000000000000000000000000000';