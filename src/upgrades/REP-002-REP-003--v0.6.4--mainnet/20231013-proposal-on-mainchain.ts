import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ProposalSegmentArguments, defaultSegment, explorerUrl, proxyInterface } from '../upgradeUtils';
import { generalMainchainConf, roninchainNetworks } from '../../configs/config';
import { companionNetworks, network } from 'hardhat';
import { MainchainGatewayV3__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    console.log('Not on Ronin chain. Abort!');
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const companionNetwork = companionNetworks['mainchain'];
  const companionNetworkName = network.companionNetworks['mainchain'];
  const companionNetworkChainId = await companionNetwork.getChainId();

  deployments.log('Using deployments on companion network. ChainId:', companionNetworkChainId);
  const MainchainBridgeManager = await companionNetwork.deployments.get('MainchainBridgeManager');
  const MainchainGatewayV3Logic = await companionNetwork.deployments.get('MainchainGatewayV3Logic');
  const MainchainGatewayV3Addr = generalMainchainConf[companionNetworkName]!.bridgeContract;

  let proposalSegments: ProposalSegmentArguments[] = [
    // Upgrade `MainchainGatewayV3` and bump initV2
    {
      ...defaultSegment,
      target: MainchainGatewayV3Addr,
      data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
        MainchainGatewayV3Logic.address,
        new MainchainGatewayV3__factory().interface.encodeFunctionData('initializeV2', [
          MainchainBridgeManager.address,
        ]),
      ]),
    },
    // Change admin of `MainchainGatewayV3` to `MainchainBridgeManager`
    {
      ...defaultSegment,
      target: MainchainGatewayV3Addr,
      data: proxyInterface.encodeFunctionData('changeAdmin', [MainchainBridgeManager.address]),
    },
  ];

  console.log(proposalSegments);
            // return; // TODO: remove when actual run

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
    'propose',

    // function propose(
    //   uint256 _chainId,
    //   uint256 _expiryTimestamp,
    //   address[] calldata _targets,
    //   uint256[] calldata _values,
    //   bytes[] calldata _calldatas,
    //   uint256[] calldata _gasAmounts
    // )

    companionNetworkChainId,
    proposalExpiryTimestamp, // expiryTimestamp
    [...proposalSegments.map((_) => _.target)], // targets
    [...proposalSegments.map((_) => _.value)], // values
    [...proposalSegments.map((_) => _.data)], // datas
    [...proposalSegments.map((_) => _.gasAmount)] // gasAmounts
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230231013__ProposalOnMainchain__V0_6_4 --network ronin-mainnet
deploy.tags = ['230231013__ProposalOnMainchain__V0_6_4'];

export default deploy;
