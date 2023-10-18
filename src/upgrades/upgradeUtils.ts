import { BigNumberish, BytesLike } from 'ethers';
import { TransparentUpgradeableProxyV2__factory } from '../types';
import { LiteralNetwork, Network } from '../utils';
import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { TargetOption } from '../script/proposal';

export const proxyInterface = new TransparentUpgradeableProxyV2__factory().interface;

export const proxyCall = (calldata: BytesLike) => proxyInterface.encodeFunctionData('functionDelegateCall', [calldata]);

interface ExplorerURLs {
  [network: LiteralNetwork]: undefined | string;
}

export interface Instance {
  RoninGovernanceAdmin?: Deployment;
  RoninValidatorSetProxy?: Deployment;
  ProfileProxy?: Deployment;
  StakingProxy?: Deployment;
  SlashIndicatorProxy?: Deployment;
  MaintenanceProxy?: Deployment;
  RoninTrustedOrganizationProxy?: Deployment;
  BridgeTrackingProxy?: Deployment;
  StakingVestingProxy?: Deployment;
  FastFinalityTrackingProxy?: Deployment;
  RoninBridgeManager?: Deployment;
  RoninGatewayV3Proxy?: Deployment;
  BridgeSlashProxy?: Deployment;
  BridgeRewardProxy?: Deployment;

  RoninValidatorSetLogic?: Deployment;
  ProfileLogic?: Deployment;
  StakingLogic?: Deployment;
  SlashIndicatorLogic?: Deployment;
  MaintenanceLogic?: Deployment;
  RoninTrustedOrganizationLogic?: Deployment;
  BridgeTrackingLogic?: Deployment;
  StakingVestingLogic?: Deployment;
  FastFinalityTrackingLogic?: Deployment;
  RoninGatewayV3Logic?: Deployment;
}

export interface ProposalSegmentArguments {
  target?: Address | TargetOption;
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
