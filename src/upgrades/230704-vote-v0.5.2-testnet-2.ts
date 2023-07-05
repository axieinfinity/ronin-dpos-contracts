/// npx hardhat deploy --tags 230704VoteTestnetV0_5_2__2 --network ronin-testnet

/// Governor who proposes this proposal must manually vote it after running this script.

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from './upgradeUtils';
import { VoteType } from '../script/proposal';
import { RoninGatewayV2__factory } from '../types';
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

  const RoninGatewayV2LogicDepl = await deployments.get('RoninGatewayV2Logic');
  const RoninGatewayV2Addr = generalRoninConf[network.name]!.bridgeContract;

  const initializeV2_SIG = new RoninGatewayV2__factory().interface.encodeFunctionData('initializeV2');

  const RoninGatewayV2Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [RoninGatewayV2LogicDepl.address, initializeV2_SIG]),
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
    [...RoninGatewayV2Instr.map(() => RoninGatewayV2Addr)], // targets
    [...RoninGatewayV2Instr].map(() => 0), // values
    [...RoninGatewayV2Instr], // datas
    [...RoninGatewayV2Instr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230627VoteTestnetV0_5_2__2'];

export default deploy;
