import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('ScheduledMaintenanceLogic', {
    contract: 'ScheduledMaintenance',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['ScheduledMaintenanceLogic'];
deploy.dependencies = ['ProxyAdmin'];

export default deploy;
