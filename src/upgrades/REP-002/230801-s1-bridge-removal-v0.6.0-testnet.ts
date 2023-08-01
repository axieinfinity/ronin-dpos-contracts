/// yarn hardhat deploy --tags 230801_S1_BridgeRemoval_V0_6_0 --network ronin-testnet

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyCall, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { RoninGatewayV2__factory } from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade current gateway to new gateway logic
  const RoninGatewayV2Addr = generalRoninConf[network.name]!.bridgeContract;
  const RoninGatewayV2LogicDepl = await deployments.get('RoninGatewayV2Logic');
  const initializeV3_SIG = new RoninGatewayV2__factory().interface.encodeFunctionData('initializeV3');
  const RoninGatewayV2Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [RoninGatewayV2LogicDepl.address, initializeV3_SIG]),
  ];

  // Upgrade current bridge tracking
  const BridgeTrackingAddrProxy = await deployments.get('BridgeTrackingProxy');
  const BridgeTrackingAddrLogic = await deployments.get('BridgeTrackingLogic');
  const BridgeTrackingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [BridgeTrackingAddrLogic.address, initializeV3_SIG]),
  ];

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
    [...RoninGatewayV2Instr.map(() => RoninGatewayV2Addr), ...BridgeTrackingInstr.map(() => BridgeTrackingAddrProxy)], // targets
    [...RoninGatewayV2Instr, ...BridgeTrackingInstr].map(() => 0), // values
    [...RoninGatewayV2Instr, ...BridgeTrackingInstr], // datas
    [...RoninGatewayV2Instr, ...BridgeTrackingInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230801_S1_BridgeRemoval_V0_6_0'];

export default deploy;
