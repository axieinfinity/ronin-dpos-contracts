import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { RoninTrustedOrganization__factory, RoninGatewayV3__factory } from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade Ronin Trusted Org Contract
  const RoninTrustedOrganizationProxy = await deployments.get('RoninTrustedOrganizationProxy');
  const RoninTrustedOrganizationLogic = await deployments.get('RoninTrustedOrganizationLogic');
  const RoninTrustedOrganizationInstr = [
    proxyInterface.encodeFunctionData('upgradeTo', [RoninTrustedOrganizationLogic.address]),
  ];
  console.info('RoninTrustedOrganizationInstr', RoninTrustedOrganizationInstr);

  // Upgrade Slash Indicator Contract
  const SlashIndicatorProxy = await deployments.get('SlashIndicatorProxy');
  const SlashIndicatorLogic = await deployments.get('SlashIndicatorLogic');
  const SlashIndicatorInstr = [proxyInterface.encodeFunctionData('upgradeTo', [SlashIndicatorLogic.address])];
  console.info('SlashIndicatorInstr', SlashIndicatorInstr);

  // Upgrade Staking Contract
  const StakingProxy = await deployments.get('StakingProxy');
  const StakingLogic = await deployments.get('StakingLogic');
  const StakingInstr = [proxyInterface.encodeFunctionData('upgradeTo', [StakingLogic.address])];
  console.info('StakingInstr', StakingInstr);

  // Upgrade Ronin Validator Set Contract
  const RoninValidatorSetProxy = await deployments.get('RoninValidatorSetProxy');
  const RoninValidatorSetLogic = await deployments.get('RoninValidatorSetLogic');
  const RoninValidatorSetInstr = [proxyInterface.encodeFunctionData('upgradeTo', [RoninValidatorSetLogic.address])];
  console.info('RoninValidatorSetInstr', RoninValidatorSetInstr);

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
    [
      ...RoninTrustedOrganizationInstr.map(() => RoninTrustedOrganizationProxy.address),
      ...SlashIndicatorInstr.map(() => SlashIndicatorProxy.address),
      ...StakingInstr.map(() => StakingProxy.address),
      ...RoninValidatorSetInstr.map(() => RoninValidatorSetProxy.address),
    ], // targets
    [...RoninTrustedOrganizationInstr, ...SlashIndicatorInstr, ...StakingInstr, ...RoninValidatorSetInstr].map(() => 0), // values
    [...RoninTrustedOrganizationInstr, ...SlashIndicatorInstr, ...StakingInstr, ...RoninValidatorSetInstr], // datas
    [...RoninTrustedOrganizationInstr, ...SlashIndicatorInstr, ...StakingInstr, ...RoninValidatorSetInstr].map(
      () => 1_000_000
    ), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230814_S7_UpgradeMissingDPoSContract_V0_6_1 --network ronin-testnet
deploy.tags = ['230814_S7_UpgradeMissingDPoSContract_V0_6_1'];

export default deploy;
