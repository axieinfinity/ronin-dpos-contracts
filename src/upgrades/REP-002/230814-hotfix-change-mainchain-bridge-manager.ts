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
  const bridgeManagerOldAddr = '0x4a0F388c8E4b46B8F16cA279fAA49396cE4cFD17';
  const bridgeManagerAddr = (await companionNetwork.deployments.get('MainchainBridgeManager')).address;
  const BridgeManagerInstr = [proxyInterface.encodeFunctionData('changeAdmin', [bridgeManagerAddr])];

  console.info('MainchainGatewayV2Instr', BridgeManagerInstr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  console.log('chainid', companionNetworkChainId); // chainid
  console.log('expiryTimestamp', proposalExpiryTimestamp); // expiryTimestamp
  console.log('targets', [...BridgeManagerInstr.map(() => bridgeManagerOldAddr)]); // targets
  console.log(
    'values',
    [...BridgeManagerInstr].map(() => 0)
  ); // values
  console.log('datas', [...BridgeManagerInstr]); // datas
  console.log(
    'gasAmounts',
    [...BridgeManagerInstr].map(() => 1_000_000)
  ); // gasAmounts

  // Hotfix, only need param, no execute.
  return;
};

// yarn hardhat deploy --tags 230804_Hotfix_ChangeMainchainBridgeManager --network ronin-testnet
deploy.tags = ['230804_Hotfix_ChangeMainchainBridgeManager'];

export default deploy;
