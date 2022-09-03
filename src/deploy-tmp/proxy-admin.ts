import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('ProxyAdmin', {
    from: deployer,
    log: true,
  });
};

deploy.tags = ['ProxyAdmin'];

export default deploy;
