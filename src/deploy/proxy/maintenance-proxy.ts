import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { maintenanceConf, initAddress } from '../../config';
import { Maintenance__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('MaintenanceLogic');

  const data = new Maintenance__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    maintenanceConf[network.name]!.minMaintenanceBlockPeriod,
    maintenanceConf[network.name]!.maxMaintenanceBlockPeriod,
    maintenanceConf[network.name]!.minOffset,
    maintenanceConf[network.name]!.maxSchedules,
  ]);

  await deploy('MaintenanceProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
  });
};

deploy.tags = ['MaintenanceProxy'];
deploy.dependencies = ['MaintenanceLogic'];

export default deploy;
