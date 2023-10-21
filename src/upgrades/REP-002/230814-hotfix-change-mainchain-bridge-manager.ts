import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { MainchainGatewayV3__factory, Proposal } from '../../types';
import { generalMainchainConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';
import { ProposalDetailStruct } from '../../types/CoreGovernance';

const deploy = async ({ getNamedAccounts, deployments, ethers, companionNetworks }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const companionNetwork = companionNetworks['mainchain'];
  const companionNetworkName = network.companionNetworks['mainchain'];
  const companionNetworkChainId = await companionNetwork.getChainId();

  // Using companion networks to get info from mainchain's deployments
  // Upgrade current gateway to new gateway logic
  deployments.log('Using deployments on companion network. ChainId:', companionNetworkChainId);
  const bridgeManagerOldAddr = '0x4a0F388c8E4b46B8F16cA279fAA49396cE4cFD17';
  const bridgeManagerAddr = (await companionNetwork.deployments.get('MainchainBridgeManager')).address;
  const MainchainGatewayV3Addr = generalMainchainConf[companionNetworkName]!.bridgeContract;
  const MainchainGatewayV3Instr = [proxyInterface.encodeFunctionData('changeAdmin', [bridgeManagerAddr])];

  console.info('MainchainGatewayV3Instr', MainchainGatewayV3Instr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const proposal: ProposalDetailStruct = {
    nonce: 0, // NOTE: do not use this
    chainId: companionNetworkChainId,
    expiryTimestamp: proposalExpiryTimestamp,
    targets: [...MainchainGatewayV3Instr.map(() => MainchainGatewayV3Addr)], // targets
    values: [...MainchainGatewayV3Instr].map(() => 0), // values
    calldatas: [...MainchainGatewayV3Instr], // datas
    gasAmounts: [...MainchainGatewayV3Instr].map(() => 1_000_000), // gasAmounts
  };

  deployments.log(proposal);

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninBridgeManager',
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

    proposal.chainId,
    proposal.expiryTimestamp,
    proposal.targets,
    proposal.values,
    proposal.calldatas,
    proposal.gasAmounts
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230804_Hotfix_ChangeMainchainBridgeManager --network ronin-testnet
deploy.tags = ['230804_Hotfix_ChangeMainchainBridgeManager'];

export default deploy;
