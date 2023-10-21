/// npx hardhat deploy --tags 230627UpgradeTestnetV0_5_2 --network ronin-testnet

/// This script does the following:
/// - Set new enforcer for mainchain gateway

/// Governor who proposes this proposal must manually vote it after running this script.

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from './upgradeUtils';
import { VoteType } from '../script/proposal';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  /// Upgrade contracts

  const GADelp = await deployments.get('RoninGovernanceAdmin'); // NOTE: Should use the previous GA contract instance.
  const newGAAddr = ''; // TODO: add new GA address here

  const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
  const MaintenanceProxy = await deployments.get('MaintenanceProxy');
  const RoninGatewayPauseEnforcerProxy = await deployments.get('RoninGatewayPauseEnforcerProxy');
  const RoninTrustedOrganizationProxy = await deployments.get('RoninTrustedOrganizationProxy');
  const RoninValidatorSetProxy = await deployments.get('RoninValidatorSetProxy');
  const SlashIndicatorProxy = await deployments.get('SlashIndicatorProxy');
  const StakingProxy = await deployments.get('StakingProxy');
  const StakingVestingProxy = await deployments.get('StakingVestingProxy');
  const RoninGatewayV3Addr = generalRoninConf[network.name]!.bridgeContract;

  const GAInstr = [
    proxyInterface.encodeFunctionData('changeProxyAdmin', [BridgeTrackingProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [MaintenanceProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [RoninGatewayPauseEnforcerProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [RoninTrustedOrganizationProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [RoninValidatorSetProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [SlashIndicatorProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [StakingProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [StakingVestingProxy.address, newGAAddr]),
    proxyInterface.encodeFunctionData('changeProxyAdmin', [RoninGatewayV3Addr, newGAAddr]),
  ];

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
    [...GAInstr.map(() => GADelp.address)], // targets
    [...GAInstr].map(() => 0), // values
    [...GAInstr], // datas
    [...GAInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230628UpgradeGA'];

export default deploy;
