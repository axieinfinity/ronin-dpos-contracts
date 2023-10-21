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
import { bridgeManagerConf } from '../../configs/bridge-manager';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const allDeployments: Instance = {
    RoninBridgeManager: await deployments.get('RoninBridgeManager'),
  };

  let proposalSegments: ProposalSegmentArguments[] = [];
  proposalSegments.push({
    value: 0,
    gasAmount: 8_000_000,
    target: TargetOption.BridgeManager,
    // target: allDeployments.RoninBridgeManager?.address, // TODO: remove me
    data: new RoninBridgeManager__factory().interface.encodeFunctionData('addBridgeOperators', [
      bridgeManagerConf[network.name]!.members?.map((_) => _.weight),
      bridgeManagerConf[network.name]!.members?.map((_) => _.governor),
      bridgeManagerConf[network.name]!.members?.map((_) => _.operator),
    ]),
  });

  proposalSegments.push({
    ...defaultSegment,
    target: TargetOption.BridgeManager,
    // target: allDeployments.RoninBridgeManager?.address, // TODO: remove me
    data: new RoninBridgeManager__factory().interface.encodeFunctionData('removeBridgeOperators', [
      ['0x32015e8b982c61bc8a593816fdbf03a603eec823'],
    ]),
  });

  // const blockFork = await ethers.provider.getBlock(28595746);
  // const timestampFork = blockFork.timestamp;
  // const proposalExpiry = timestampFork + 3600 * 24 * 10; // expired in 10 days

  // const proposeProposalRaw = new RoninBridgeManager__factory().interface.encodeFunctionData(
  //   'proposeProposalForCurrentNetwork',
  //   [
  //     proposalExpiry,
  //     [...proposalSegments.map((_) => _.target)], // targets
  //     [...proposalSegments.map((_) => _.value)], // values
  //     [...proposalSegments.map((_) => _.data)], // datas
  //     [...proposalSegments.map((_) => _.gasAmount)], // gasAmounts
  //     VoteType.For,
  //   ]
  // );

  // console.log('proposeProposalRaw');
  // console.log(proposeProposalRaw);

  // return;

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const tx = await execute(
    'RoninBridgeManager',
    { from: governor, log: true },
    'proposeGlobal',

    // uint256 expiryTimestamp,
    // GlobalProposal.TargetOption[] calldata targetOptions,
    // uint256[] calldata values,
    // bytes[] calldata calldatas,
    // uint256[] calldata gasAmounts

    proposalExpiryTimestamp, // expiryTimestamp
    [...proposalSegments.map((_) => _.target)], // targets
    [...proposalSegments.map((_) => _.value)], // values
    [...proposalSegments.map((_) => _.data)], // datas
    [...proposalSegments.map((_) => _.gasAmount)] // gasAmounts
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 231017_AddBridgeManagersBothChain --network ronin-mainnet
deploy.tags = ['231017_AddBridgeManagersBothChain'];

export default deploy;
