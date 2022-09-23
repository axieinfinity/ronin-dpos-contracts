import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MaintenanceLogic', {
    contract: 'Maintenance',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['MaintenanceLogic'];
deploy.dependencies = ['ProxyAdmin'];

export default deploy;
