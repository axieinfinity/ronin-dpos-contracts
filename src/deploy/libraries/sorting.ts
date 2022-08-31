import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SortingLibrary', {
    contract: 'Sorting',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['SortingLibrary'];

export default deploy;
