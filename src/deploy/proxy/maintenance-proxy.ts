import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { maintenanceConf, generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { Maintenance__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('MaintenanceLogic');

  const data = new Maintenance__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.validatorContract?.address,
    maintenanceConf[network.name]!.minMaintenanceDurationInBlock,
    maintenanceConf[network.name]!.maxMaintenanceDurationInBlock,
    maintenanceConf[network.name]!.minOffsetToStartSchedule,
    maintenanceConf[network.name]!.maxOffsetToStartSchedule,
    maintenanceConf[network.name]!.maxSchedules,
    maintenanceConf[network.name]!.cooldownSecsToMaintain,
  ]);

  const nonce = generalRoninConf[network.name].maintenanceContract?.nonce;
  // console.log(`Deploying MaintenanceProxy (nonce: ${nonce})...`);

  const deployment = await deploy('MaintenanceProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].maintenanceContract?.address);
};

deploy.tags = ['MaintenanceProxy'];
deploy.dependencies = ['MaintenanceLogic', '_HelperDposCalculate', 'RoninTrustedOrganizationProxy'];

export default deploy;
