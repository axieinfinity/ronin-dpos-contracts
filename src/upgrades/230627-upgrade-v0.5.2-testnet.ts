/// npx hardhat deploy --tags 230627UpgradeTestnetV0_5_2 --network ronin-testnet

/// This script does the following:
/// - Set new enforcer for mainchain gateway

/// Governor who proposes this proposal must manually vote it after running this script.

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyCall, proxyInterface } from './upgradeUtils';
import { VoteType } from '../script/proposal';
import { RoninGatewayV3__factory, SlashIndicator__factory } from '../types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  /// Upgrade contracts

  const BridgeTrackingLogicDepl = await deployments.get('BridgeTrackingLogic');
  const MaintenanceLogicDepl = await deployments.get('MaintenanceLogic');
  const RoninGatewayV3LogicDepl = await deployments.get('RoninGatewayV3Logic');
  const RoninValidatorSetLogicDepl = await deployments.get('RoninValidatorSetLogic');
  const SlashIndicatorLogicDepl = await deployments.get('SlashIndicatorLogic');
  const StakingLogicDepl = await deployments.get('StakingLogic');
  const StakingVestingLogicDepl = await deployments.get('StakingVestingLogic');
  const RoninGovernanceAdminDepl = await deployments.get('RoninGovernanceAdmin');

  const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
  const MaintenanceProxy = await deployments.get('MaintenanceProxy');
  const RoninValidatorSetProxy = await deployments.get('RoninValidatorSetProxy');
  const SlashIndicatorProxy = await deployments.get('SlashIndicatorProxy');
  const StakingProxy = await deployments.get('StakingProxy');
  const StakingVestingProxy = await deployments.get('StakingVestingProxy');
  const RoninGatewayPauseEnforcerProxy = await deployments.get('RoninGatewayPauseEnforcerProxy');
  const RoninGatewayV3Addr = generalRoninConf[network.name]!.bridgeContract;

  const initializeV2_SIG = new RoninGatewayV3__factory().interface.encodeFunctionData('initializeV2');

  const BridgeTrackingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [BridgeTrackingLogicDepl.address, initializeV2_SIG]),
  ];
  const MaintenanceInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [MaintenanceLogicDepl.address, initializeV2_SIG]),
  ];
  const RoninGatewayV3Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [RoninGatewayV3LogicDepl.address, initializeV2_SIG]),
    proxyCall(
      new RoninGatewayV3__factory().interface.encodeFunctionData('setEmergencyPauser', [
        RoninGatewayPauseEnforcerProxy.address,
      ])
    ),
  ];
  const RoninValidatorSetInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [RoninValidatorSetLogicDepl.address, initializeV2_SIG]),
  ];
  const SlashIndicatorInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      SlashIndicatorLogicDepl.address,
      new SlashIndicator__factory().interface.encodeFunctionData('initializeV2', [RoninGovernanceAdminDepl.address]),
    ]),
  ];
  const StakingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [StakingLogicDepl.address, initializeV2_SIG]),
  ];
  const StakingVestingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [StakingVestingLogicDepl.address, initializeV2_SIG]),
  ];

  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [
      ...BridgeTrackingInstr.map(() => BridgeTrackingProxy.address),
      ...MaintenanceInstr.map(() => MaintenanceProxy.address),
      ...RoninGatewayV3Instr.map(() => RoninGatewayV3Addr),
      ...RoninValidatorSetInstr.map(() => RoninValidatorSetProxy.address),
      ...SlashIndicatorInstr.map(() => SlashIndicatorProxy.address),
      ...StakingInstr.map(() => StakingProxy.address),
      ...StakingVestingInstr.map(() => StakingVestingProxy.address),
    ], // targets
    [
      ...BridgeTrackingInstr,
      ...MaintenanceInstr,
      ...RoninGatewayV3Instr,
      ...RoninValidatorSetInstr,
      ...SlashIndicatorInstr,
      ...StakingInstr,
      ...StakingVestingInstr,
    ].map(() => 0), // values
    [
      ...BridgeTrackingInstr,
      ...MaintenanceInstr,
      ...RoninGatewayV3Instr,
      ...RoninValidatorSetInstr,
      ...SlashIndicatorInstr,
      ...StakingInstr,
      ...StakingVestingInstr,
    ], // datas
    [
      ...BridgeTrackingInstr,
      ...MaintenanceInstr,
      ...RoninGatewayV3Instr,
      ...RoninValidatorSetInstr,
      ...SlashIndicatorInstr,
      ...StakingInstr,
      ...StakingVestingInstr,
    ].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230627UpgradeTestnetV0_5_2'];

export default deploy;
