import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from './upgradeUtils';
import { VoteType } from '../script/proposal';
import { BridgeTracking__factory, RoninGatewayV2__factory } from '../types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { BigNumber } from 'ethers';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade current bridge tracking
  const bridgeInterface = new RoninGatewayV2__factory().interface;
  const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
  const instr = [
    proxyInterface.encodeFunctionData('functionDelegateCall', [
      bridgeInterface.encodeFunctionData('setContract', [
          3, BridgeTrackingProxy.address,
      ]),
    ]),
  ];

  console.info('Instructions', instr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninBridgeManager',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...instr.map(() => "0xcee681c9108c42c710c6a8a949307d5f13c9f3ca")], // targets
    [...instr].map(() => 0), // values
    [...instr], // datas
    [...instr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230824_SetMinThresholdUSDC --network ronin-testnet
deploy.tags = ['231009_SetBridgeTrackingContract'];

export default deploy;
