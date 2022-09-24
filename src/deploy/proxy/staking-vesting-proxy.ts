import { BigNumber } from 'ethers';
import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { initAddress, stakingVestingConfig } from '../../config';
import { StakingVesting__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('StakingVestingLogic');

  const data = new StakingVesting__factory().interface.encodeFunctionData('initialize', [
    stakingVestingConfig[network.name]!.bonusPerBlock,
    initAddress[network.name]!.validatorContract,
  ]);

  await deploy('StakingVestingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
    value: BigNumber.from(stakingVestingConfig[network.name]!.topupAmount),
  });
};

deploy.tags = ['StakingVestingProxy'];
deploy.dependencies = ['StakingVestingLogic', 'MaintenanceProxy'];

export default deploy;
