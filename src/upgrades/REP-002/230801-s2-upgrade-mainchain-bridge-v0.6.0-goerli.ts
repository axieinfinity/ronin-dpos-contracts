import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { MainchainGatewayV2__factory } from '../../types';
import { generalMainchainConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

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
  const bridgeManagerAddr = (await companionNetwork.deployments.get('MainchainBridgeManager')).address;
  const MainchainGatewayV2Addr = generalMainchainConf[companionNetworkName]!.bridgeContract;
  const MainchainGatewayV2LogicDepl = await companionNetwork.deployments.get('MainchainGatewayV2Logic');
  const MainchainGatewayV2Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      MainchainGatewayV2LogicDepl.address,
      new MainchainGatewayV2__factory().interface.encodeFunctionData('initializeV2', [bridgeManagerAddr]),
    ]),
  ];

  console.info('MainchainGatewayV2Instr', MainchainGatewayV2Instr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
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
    [...MainchainGatewayV2Instr.map(() => MainchainGatewayV2Addr)], // targets
    [...MainchainGatewayV2Instr].map(() => 0), // values
    [...MainchainGatewayV2Instr], // datas
    [...MainchainGatewayV2Instr].map(() => 1_000_000) // gasAmounts
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230801_S2_UpgradeMainchainBridge_V0_6_0 --network ronin-testnet
deploy.tags = ['230801_S2_UpgradeMainchainBridge_V0_6_0'];

export default deploy;
