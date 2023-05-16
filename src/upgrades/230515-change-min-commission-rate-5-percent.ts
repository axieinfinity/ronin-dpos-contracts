/// npx hardhat deploy --tags 230515ChangeMinCommissionRate5Percent --network ronin-mainnet

/// This script does the following:
/// - Upgrade Maintenance, Staking, Validator contract
/// - Set `minCommissionRate`

import { BigNumber } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { VoteType } from '../script/proposal';
import { Staking__factory } from '../types';
import { StakingArguments } from '../utils';
import { proxyCall, proxyInterface } from './upgradeUtils';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  /// Upgrade contracts

  const newMaintenanceLogic = '0xB6a13e481f060c6a9130238EEb84a3c98A0A5FEa';
  const newValidatorSetLogic = '0xaB2985fa821CAae0524f6C5657aE40DaBDf2Eae0';
  const newStakingLogic = '0x9B0E61e629EB44875CFf534DE0c176078CaC502f';

  const maintenanceProxy = await deployments.get('MaintenanceProxy');
  const validatorSetProxy = await deployments.get('ValidatorSetProxy');
  const stakingProxy = await deployments.get('StakingProxy');

  const maintenanceInstructions = [proxyInterface.encodeFunctionData('upgradeTo', [newMaintenanceLogic])];
  const validatorSetInstructions = [proxyInterface.encodeFunctionData('upgradeTo', [newValidatorSetLogic])];

  /// Set `minCommissionRate`

  const StakingInterface = new Staking__factory().interface;
  const newStakingConfig: StakingArguments = {
    minCommissionRate: BigNumber.from(5_00),
    maxCommissionRate: BigNumber.from(20_00),
  };

  const stakingInstructions = [
    proxyInterface.encodeFunctionData('upgradeTo', [newStakingLogic]),
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
    [
      ...maintenanceInstructions.map(() => maintenanceProxy.address),
      ...validatorSetInstructions.map(() => validatorSetProxy.address),
      ...stakingInstructions.map(() => stakingProxy.address),
    ], // targets
    [...maintenanceInstructions, ...validatorSetInstructions, ...stakingInstructions].map(() => 0), // values
    [...maintenanceInstructions, ...validatorSetInstructions, ...stakingInstructions], // datas
    [...maintenanceInstructions, ...validatorSetInstructions, ...stakingInstructions].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`https://explorer.roninchain.com/tx/${tx.transactionHash}`);
};

deploy.tags = ['230515ChangeMinCommissionRate5Percent'];

export default deploy;
