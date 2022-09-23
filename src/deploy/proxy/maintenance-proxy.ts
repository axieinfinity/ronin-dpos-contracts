import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { MaintenanceConfig, initAddress } from '../../config';
import { Maintenance__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('MaintenanceLogic');

  const data = new Maintenance__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    MaintenanceConfig[network.name]!.minMaintenanceBlockPeriod,
    MaintenanceConfig[network.name]!.maxMaintenanceBlockPeriod,
    MaintenanceConfig[network.name]!.minOffset,
    MaintenanceConfig[network.name]!.maxSchedules,
  ]);

  await deploy('MaintenanceProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['MaintenanceProxy'];
deploy.dependencies = ['ProxyAdmin', 'MaintenanceLogic'];

export default deploy;
