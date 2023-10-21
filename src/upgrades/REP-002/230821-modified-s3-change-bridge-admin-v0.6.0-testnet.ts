import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
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

  // Change Admin of Bridge to Bridge Manager
  const RoninGatewayV3Addr = generalRoninConf[network.name]!.bridgeContract;
  const RoninGatewayV3Instr = [proxyInterface.encodeFunctionData('changeAdmin', [bridgeManagerAddr])];

  console.log('bridgeManagerAddr', bridgeManagerAddr);
  console.log('RoninGatewayV3Addr', RoninGatewayV3Addr);
  console.info('RoninGatewayV3Instr', RoninGatewayV3Instr);

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
    [...RoninGatewayV3Instr.map(() => RoninGatewayV3Addr)], // targets
    [...RoninGatewayV3Instr].map(() => 0), // values
    [...RoninGatewayV3Instr], // datas
    [...RoninGatewayV3Instr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230821_ModifiedS3_ChangeAdminOfBridge --network ronin-testnet
deploy.tags = ['230821_ModifiedS3_ChangeAdminOfBridge'];

export default deploy;
