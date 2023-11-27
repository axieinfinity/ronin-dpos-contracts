import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';
import { Maintenance__factory, Profile__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade Profile Contract
  const MaintenanceProxy = await deployments.get('MaintenanceProxy');
  const MaintenanceLogic = await deployments.get('MaintenanceLogic');
  const MaintenanceInstr = [proxyInterface.encodeFunctionData('upgradeTo', [MaintenanceLogic.address])];
  console.info('ProfileInstr', MaintenanceInstr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...MaintenanceInstr.map(() => MaintenanceProxy.address)], // targets
    [...MaintenanceInstr].map(() => 0), // values
    [...MaintenanceInstr], // datas
    [...MaintenanceInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 231103_UpgradeMaintenance --network ronin-testnet
deploy.tags = ['231103_UpgradeMaintenance'];

export default deploy;
