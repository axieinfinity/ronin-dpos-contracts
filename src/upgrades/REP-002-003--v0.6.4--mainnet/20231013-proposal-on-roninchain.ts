import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks, stakingVestingConfig } from '../../configs/config';
import { deployments, network } from 'hardhat';
import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { BigNumberish, BytesLike } from 'ethers';
import {
  BridgeTracking__factory,
  RoninTrustedOrganization__factory,
  RoninValidatorSet__factory,
  SlashIndicator__factory,
  StakingVesting__factory,
  Staking__factory,
} from '../../types';

interface ProposalSegmentArguments {
  target?: Address;
  values: BigNumberish;
  data?: BytesLike;
  gasAmounts: BigNumberish;
}

interface Instance {
  RoninGovernanceAdmin: Deployment;
  RoninValidatorSetProxy: Deployment;
  ProfileProxy: Deployment;
  StakingProxy: Deployment;
  SlashIndicatorProxy: Deployment;
  RoninTrustedOrganizationProxy: Deployment;
  BridgeTrackingProxy: Deployment;
  StakingVestingProxy: Deployment;
  FastFinalityTrackingProxy: Deployment;
  RoninValidatorSetLogic: Deployment;
  ProfileLogic: Deployment;
  StakingLogic: Deployment;
  SlashIndicatorLogic: Deployment;
  RoninTrustedOrganizationLogic: Deployment;
  BridgeTrackingLogic: Deployment;
  StakingVestingLogic: Deployment;
  FastFinalityTrackingLogic: Deployment;
}

const defaultSegment: ProposalSegmentArguments = {
  gasAmounts: 1_000_000,
  values: 0,
};

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const allDeployments: Instance = {
    RoninGovernanceAdmin: await deployments.get('RoninGovernanceAdmin'),
    RoninValidatorSetProxy: await deployments.get('RoninValidatorSetProxy'),
    ProfileProxy: await deployments.get('ProfileProxy'),
    StakingProxy: await deployments.get('StakingProxy'),
    SlashIndicatorProxy: await deployments.get('SlashIndicatorProxy'),
    RoninTrustedOrganizationProxy: await deployments.get('RoninTrustedOrganizationProxy'),
    BridgeTrackingProxy: await deployments.get('BridgeTrackingProxy'),
    StakingVestingProxy: await deployments.get('StakingVestingProxy'),
    FastFinalityTrackingProxy: await deployments.get('FastFinalityTrackingProxy'),
    RoninValidatorSetLogic: await deployments.get('RoninValidatorSetLogic'),
    ProfileLogic: await deployments.get('ProfileLogic'),
    StakingLogic: await deployments.get('StakingLogic'),
    SlashIndicatorLogic: await deployments.get('SlashIndicatorLogic'),
    RoninTrustedOrganizationLogic: await deployments.get('RoninTrustedOrganizationLogic'),
    BridgeTrackingLogic: await deployments.get('BridgeTrackingLogic'),
    StakingVestingLogic: await deployments.get('StakingVestingLogic'),
    FastFinalityTrackingLogic: await deployments.get('FastFinalityTrackingLogic'),
  };

  //      Upgrade DPoS Contracts
  //      See `script/20231003-rep-002-rep-003/20231003_REP002AndREP003_RON_NonConditional.s.sol`
  let proposalPart1 = await upgradeDPoSContractSetProposalPart(allDeployments);

  //      Upgrade Gateway Contracts
  //      See `script/20231003-rep-002-rep-003/20231003_REP002AndREP003_RON_NonConditional.s.sol`
  let proposalPart2 = await upgradeGatewayContractSetProposalPart(allDeployments);

  //////////////////////////////////////////
  //          Propose the proposal
  //////////////////////////////////////////
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    // [...ProfileInstr.map(() => ProfileProxy.address)], // targets
    // [...ProfileInstr].map(() => 0), // values
    // [...ProfileInstr], // datas
    // [...ProfileInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230231013__ProposalOnRoninChain__V0_6_4 --network ronin-mainnet
deploy.tags = ['230231013__ProposalOnRoninChain__V0_6_4'];

export default deploy;

async function upgradeDPoSContractSetProposalPart(instance: Instance): Promise<ProposalSegmentArguments[]> {
  let segments: ProposalSegmentArguments[] = [];

  // upgrade `RoninValidatorSet` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.RoninValidatorSetProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.RoninValidatorSetLogic.address,
      new RoninValidatorSet__factory().interface.encodeFunctionData('initializeV2'),
    ]),
  });

  // bump `RoninValidatorSet` to V3
  segments.push({
    ...defaultSegment,
    target: instance.RoninValidatorSetProxy.address,
    data: new RoninValidatorSet__factory().interface.encodeFunctionData('initializeV3', [
      instance.FastFinalityTrackingProxy.address,
    ]),
  });

  // upgrade `Staking` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.StakingProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.StakingLogic.address,
      new Staking__factory().interface.encodeFunctionData('initializeV2'),
    ]),
  });

  // upgrade `SlashIndicator` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.SlashIndicatorProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.SlashIndicatorLogic.address,
      new SlashIndicator__factory().interface.encodeFunctionData('initializeV2', [RoninGovernanceAdmin.address]),
    ]),
  });

  // bump `SlashIndicator` to V3
  segments.push({
    ...defaultSegment,
    target: instance.SlashIndicatorProxy.address,
    data: new SlashIndicator__factory().interface.encodeFunctionData('initializeV3', [ProfileProxy.address]),
  });

  // upgrade `RoninTrustedOrganization`
  segments.push({
    ...defaultSegment,
    target: instance.RoninTrustedOrganizationProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeTo', [instance.RoninTrustedOrganizationLogic.address]),
  });

  // upgrade `BridgeTracking` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.BridgeTrackingProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.BridgeTrackingLogic.address,
      new BridgeTracking__factory().interface.encodeFunctionData('initializeV2'),
    ]),
  });

  // upgrade `StakingVesting` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.StakingVestingProxy.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.StakingVestingLogic.address,
      new StakingVesting__factory().interface.encodeFunctionData('initializeV2'),
    ]),
  });

  // bump `StakingVesting` to V3
  segments.push({
    ...defaultSegment,
    target: instance.StakingVestingProxy.address,
    data: new StakingVesting__factory().interface.encodeFunctionData('initializeV3', [
      stakingVestingConfig[network.name]?.fastFinalityRewardPercent!,
    ]),
  });

  return segments;
}

async function upgradeGatewayContractSetProposalPart(instance: Instance): Promise<ProposalSegmentArguments[]> {}
