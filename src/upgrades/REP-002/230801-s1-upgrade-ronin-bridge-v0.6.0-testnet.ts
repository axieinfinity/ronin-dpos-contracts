import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { BridgeTracking__factory, RoninGatewayV3__factory } from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Common initialization input
  const bridgeManagerAddr = (await deployments.get('RoninBridgeManager')).address;
  const bridgeSlashAddr = (await deployments.get('BridgeSlashProxy')).address;
  const bridgeRewardAddr = (await deployments.get('BridgeRewardProxy')).address;

  // Upgrade current gateway to new gateway logic
  const RoninGatewayV3Addr = generalRoninConf[network.name]!.bridgeContract;
  const RoninGatewayV3LogicDepl = await deployments.get('RoninGatewayV3Logic');
  const RoninGatewayV3Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      RoninGatewayV3LogicDepl.address,
      new RoninGatewayV3__factory().interface.encodeFunctionData('initializeV3', [bridgeManagerAddr]),
    ]),
  ];

  console.info('RoninGatewayV3Instr', RoninGatewayV3Instr);

  // Upgrade current bridge tracking
  const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
  const BridgeTrackingLogic = await deployments.get('BridgeTrackingLogic');
  const BridgeTrackingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      BridgeTrackingLogic.address,
      new BridgeTracking__factory().interface.encodeFunctionData('initializeV2'),
    ]),
    proxyInterface.encodeFunctionData('functionDelegateCall', [
      new BridgeTracking__factory().interface.encodeFunctionData('initializeV3', [
        bridgeManagerAddr,
        bridgeSlashAddr,
        bridgeRewardAddr,
      ]),
    ]),
  ];

  console.info('BridgeTrackingInstr', BridgeTrackingInstr);

  // Propose the proposal
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
      ...RoninGatewayV3Instr.map(() => RoninGatewayV3Addr),
      ...BridgeTrackingInstr.map(() => BridgeTrackingProxy.address),
    ], // targets
    [...RoninGatewayV3Instr, ...BridgeTrackingInstr].map(() => 0), // values
    [...RoninGatewayV3Instr, ...BridgeTrackingInstr], // datas
    [...RoninGatewayV3Instr, ...BridgeTrackingInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230801_S1_UpgradeRoninBridge_V0_6_0 --network ronin-testnet
deploy.tags = ['230801_S1_UpgradeRoninBridge_V0_6_0'];

export default deploy;
