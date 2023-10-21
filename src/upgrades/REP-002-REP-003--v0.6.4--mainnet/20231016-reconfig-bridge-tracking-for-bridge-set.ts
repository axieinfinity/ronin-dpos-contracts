import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Instance, ProposalSegmentArguments, defaultSegment, explorerUrl, proxyInterface } from '../upgradeUtils';
import { TargetOption, VoteType } from '../../script/proposal';
import {
  BridgeSlash__factory,
  BridgeTracking__factory,
  RoninBridgeManager__factory,
  RoninGatewayV3__factory,
} from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';
import { BigNumber } from 'ethers';
import { ContractType } from '../../../test/hardhat_test/helpers/utils';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const allDeployments: Instance = {
    BridgeTrackingProxy: await deployments.get('BridgeTrackingProxy'),
    RoninBridgeManager: await deployments.get('RoninBridgeManager'),
    BridgeSlashProxy: await deployments.get('BridgeSlashProxy'),
    BridgeRewardProxy: await deployments.get('BridgeRewardProxy'),
  };

  //      Upgrade DPoS Contracts
  //      See `script/20231003-rep-002-rep-003/20231003_REP002AndREP003_RON_NonConditional.s.sol`
  let proposalSegments: ProposalSegmentArguments[] = [];
  proposalSegments.push({
    ...defaultSegment,
    target: allDeployments.RoninBridgeManager!.address,
    data: new RoninBridgeManager__factory().interface.encodeFunctionData('updateManyTargetOption', [
      [TargetOption.BridgeTracking],
      [allDeployments.BridgeTrackingProxy!.address],
    ]),
  });

  proposalSegments.push({
    ...defaultSegment,
    target: allDeployments.BridgeSlashProxy!.address,
    data: proxyInterface.encodeFunctionData('functionDelegateCall', [
      new BridgeSlash__factory().interface.encodeFunctionData('setContract', [
        ContractType.BRIDGE_TRACKING,
        allDeployments.BridgeTrackingProxy!.address,
      ]),
    ]),
  });

  proposalSegments.push({
    ...defaultSegment,
    target: allDeployments.BridgeRewardProxy!.address,
    data: proxyInterface.encodeFunctionData('functionDelegateCall', [
      new BridgeSlash__factory().interface.encodeFunctionData('setContract', [
        ContractType.BRIDGE_TRACKING,
        allDeployments.BridgeTrackingProxy!.address,
      ]),
    ]),
  });

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const tx = await execute(
    'RoninBridgeManager',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...proposalSegments.map((_) => _.target)], // targets
    [...proposalSegments.map((_) => _.value)], // values
    [...proposalSegments.map((_) => _.data)], // datas
    [...proposalSegments.map((_) => _.gasAmount)], // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 231016_ReconfigBridgeTracking --network ronin-mainnet
deploy.tags = ['231016_ReconfigBridgeTracking'];

export default deploy;
