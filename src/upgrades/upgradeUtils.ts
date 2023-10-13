import { BigNumberish, BytesLike } from 'ethers';
import { TransparentUpgradeableProxyV2__factory } from '../types';
import { LiteralNetwork, Network } from '../utils';
import { Address } from 'hardhat-deploy/dist/types';

export const proxyInterface = new TransparentUpgradeableProxyV2__factory().interface;

export const proxyCall = (calldata: BytesLike) => proxyInterface.encodeFunctionData('functionDelegateCall', [calldata]);

interface ExplorerURLs {
  [network: LiteralNetwork]: undefined | string;
}

export interface ProposalSegmentArguments {
  target?: Address;
  value: BigNumberish;
  data?: BytesLike;
  gasAmount: BigNumberish;
}

export const defaultSegment: ProposalSegmentArguments = {
  gasAmount: 1_000_000,
  value: 0,
};

export const explorerUrl: ExplorerURLs = {
  [Network.Hardhat]: undefined,
  [Network.Goerli]: 'https://goerli.etherscan.io',
  [Network.Testnet]: 'https://saigon-app.roninchain.com',
  [Network.Mainnet]: 'https://app.roninchain.com',
};
