import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { BridgeTracking__factory, RoninGatewayV2__factory } from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade current bridge tracking
  const BridgeTrackingProxyAddr = '0x874ad3ACb2801733c3fbE31a555d430Ce3A138Ed';
  const BridgeTrackingLogicAddr = '0xFE9E7D097F4493182308AC2Ad7CF88f21193fF4A';
  const BridgeTrackingInstr = [proxyInterface.encodeFunctionData('upgradeTo', [BridgeTrackingLogicAddr])];

  console.info('BridgeTrackingInstr', BridgeTrackingInstr);

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
    [...BridgeTrackingInstr.map(() => BridgeTrackingProxyAddr)], // targets
    [...BridgeTrackingInstr].map(() => 0), // values
    [...BridgeTrackingInstr], // datas
    [...BridgeTrackingInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230808_Rollback_S1T2_BridgeTracking_V0_6_0 --network ronin-testnet
deploy.tags = ['230808_Rollback_S1T2_BridgeTracking_V0_6_0'];

export default deploy;
