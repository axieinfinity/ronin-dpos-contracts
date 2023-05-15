/// npx hardhat deploy --tags 230515ChangeMinCommissionRate5Percent --network ronin-mainnet

import { BigNumber } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { VoteType } from '../script/proposal';
import { Staking__factory } from '../types';
import { StakingArguments } from '../utils';
import { proxyCall } from './upgradeUtils';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const stakingProxy = await deployments.get('StakingProxy');

  const StakingInterface = new Staking__factory().interface;
  const newStakingConfig: StakingArguments = {
    minCommissionRate: BigNumber.from(5_00),
    maxCommissionRate: BigNumber.from(20_00),
  };

  const stakingInstructions = [
    proxyCall(
      StakingInterface.encodeFunctionData('setCommissionRateRange', [
        newStakingConfig.minCommissionRate,
        newStakingConfig.maxCommissionRate,
      ])
    ),
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
    stakingInstructions.map(() => stakingProxy.address), // targets
    stakingInstructions.map(() => 0), // values
    stakingInstructions, // datas
    stakingInstructions.map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`https://explorer.roninchain.com/tx/${tx.transactionHash}`);
};

deploy.tags = ['230515ChangeMinCommissionRate5Percent'];

export default deploy;
