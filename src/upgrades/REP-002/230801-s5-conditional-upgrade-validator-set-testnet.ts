import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade current gateway to new gateway logic
  const timedMigratorDelp = await deployments.get('RoninValidatorSetTimedMigrator');
  const validatorSetProxyDepl = await deployments.get('RoninValidatorSetProxy');

  const ValidatorSetInstr = [proxyInterface.encodeFunctionData('upgradeTo', [timedMigratorDelp.address])];

  console.info('ValidatorSetInstr', ValidatorSetInstr);

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
    [...ValidatorSetInstr.map(() => validatorSetProxyDepl.address)], // targets
    [...ValidatorSetInstr].map(() => 0), // values
    [...ValidatorSetInstr], // datas
    [...ValidatorSetInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230801_S5_ConditionalUpgradeValidatorSet_V0_6_0 --network ronin-testnet
deploy.tags = ['230801_S5_ConditionalUpgradeValidatorSet_V0_6_0'];

export default deploy;
