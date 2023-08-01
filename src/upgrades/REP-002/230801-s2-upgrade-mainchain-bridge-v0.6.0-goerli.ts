import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyCall, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { BridgeTracking__factory, MainchainGatewayV2__factory, RoninGatewayV2__factory } from '../../types';
import { generalMainchainConf, generalRoninConf, mainchainNetworks, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Common initialization input
  const bridgeManagerAddr = (await deployments.get('MainchainBridgeManager')).address;

  // Upgrade current gateway to new gateway logic
  const MainchainGatewayV2Addr = generalMainchainConf[network.name]!.bridgeContract;
  const MainchainGatewayV2LogicDepl = await deployments.get('RoninGatewayV2Logic');
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
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...MainchainGatewayV2Instr.map(() => MainchainGatewayV2Addr)], // targets
    [...MainchainGatewayV2Instr].map(() => 0), // values
    [...MainchainGatewayV2Instr], // datas
    [...MainchainGatewayV2Instr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230801_S2_UpgradeMainchainBridge_V0_6_0 --network goerli
deploy.tags = ['230801_S2_UpgradeMainchainBridge_V0_6_0'];

export default deploy;
