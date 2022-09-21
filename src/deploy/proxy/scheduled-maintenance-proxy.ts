import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { scheduledMaintenanceConfig, initAddress } from '../../config';
import { ScheduledMaintenance__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('ScheduledMaintenanceLogic');

  const data = new ScheduledMaintenance__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    scheduledMaintenanceConfig[network.name]!.minMaintenanceBlockSize,
    scheduledMaintenanceConfig[network.name]!.maxMaintenanceBlockSize,
    scheduledMaintenanceConfig[network.name]!.minOffset,
    scheduledMaintenanceConfig[network.name]!.maxSchedules,
  ]);

  await deploy('ScheduledMaintenanceProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['ScheduledMaintenanceProxy'];
deploy.dependencies = ['ProxyAdmin', 'ScheduledMaintenanceLogic'];

export default deploy;
