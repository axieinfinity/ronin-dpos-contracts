import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';
import { Profile__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  // Upgrade Profile Contract
  const ProfileProxy = await deployments.get('ProfileProxy');
  const ProfileLogic = await deployments.get('ProfileLogic');
  const ProfileInstr = [proxyInterface.encodeFunctionData('upgradeTo', [ProfileLogic.address])];
  console.info('ProfileInstr', ProfileInstr);

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
    [...ProfileInstr.map(() => ProfileProxy.address)], // targets
    [...ProfileInstr].map(() => 0), // values
    [...ProfileInstr], // datas
    [...ProfileInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230929_UpgradeAndInitV1ProfileContractV0_6_4 --network ronin-testnet
deploy.tags = ['230929_UpgradeAndInitV1ProfileContractV0_6_4'];

export default deploy;
