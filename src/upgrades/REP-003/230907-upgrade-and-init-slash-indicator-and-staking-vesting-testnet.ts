import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks, stakingVestingConfig } from '../../configs/config';
import { network } from 'hardhat';
import { SlashIndicator__factory, StakingVesting__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const ProfileContractProxyDelp = await deployments.get('ProfileProxy');

  // Upgrade Slash Indicator Contract
  const SlashIndicatorProxy = await deployments.get('SlashIndicatorProxy');
  const SlashIndicatorLogic = await deployments.get('SlashIndicatorLogic');
  const SlashIndicatorInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      SlashIndicatorLogic.address,
      new SlashIndicator__factory().interface.encodeFunctionData('initializeV3', [ProfileContractProxyDelp.address]),
    ]),
  ];
  console.info('SlashIndicatorInstr', SlashIndicatorInstr);

  // Upgrade Staking Contract
  const StakingVestingProxy = await deployments.get('StakingVestingProxy');
  const StakingVestingLogic = await deployments.get('StakingVestingLogic');
  const StakingVestingInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      StakingVestingLogic.address,
      new StakingVesting__factory().interface.encodeFunctionData('initializeV3', [
        stakingVestingConfig[network.name]?.fastFinalityRewardPercent,
      ]),
    ]),
  ];
  console.info('StakingVestingInstr', StakingVestingInstr);

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
    [
      ...SlashIndicatorInstr.map(() => SlashIndicatorProxy.address),
      ...StakingVestingInstr.map(() => StakingVestingProxy.address),
    ], // targets
    [...SlashIndicatorInstr, ...StakingVestingInstr].map(() => 0), // values
    [...SlashIndicatorInstr, ...StakingVestingInstr], // datas
    [...SlashIndicatorInstr, ...StakingVestingInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230907_UpgradeAndInitV3SlashIndicatorAndStakingVesting_V0_6_2 --network ronin-testnet
deploy.tags = ['230907_UpgradeAndInitV3SlashIndicatorAndStakingVesting_V0_6_2'];

export default deploy;
