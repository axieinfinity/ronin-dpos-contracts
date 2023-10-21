import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { BridgeTracking__factory, RoninGatewayV3__factory } from '../../types';
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
  const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
  const BridgeTrackingLogic = await deployments.get('BridgeTrackingLogic');
  const BridgeTrackingInstr = [proxyInterface.encodeFunctionData('upgradeTo', [BridgeTrackingLogic.address])];

  console.info('BridgeTrackingInstr', BridgeTrackingInstr);

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninBridgeManager',
    { from: governor, log: true },
    'castProposalVoteForCurrentNetwork',

    // uint256 nonce;
    // uint256 chainId;
    // uint256 expiryTimestamp;
    // address[] targets;
    // uint256[] values;
    // bytes[] calldatas;
    // uint256[] gasAmounts;

    [
      2,
      2021,
      '1692348507', // expiryTimestamp
      [...BridgeTrackingInstr.map(() => BridgeTrackingProxy.address)], // targets
      [...BridgeTrackingInstr].map(() => 0), // values
      [...BridgeTrackingInstr], // datas
      [...BridgeTrackingInstr].map(() => 1_000_000),
    ], // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230808_Vote_Rollback_S1T3_BridgeTracking_V0_6_0 --network ronin-testnet
deploy.tags = ['230808_Vote_Rollback_S1T3_BridgeTracking_V0_6_0'];

export default deploy;
