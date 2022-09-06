import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { Staking__factory } from '../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  let { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const stakingLogic = await deploy('StakingLogic', {
    contract: 'Staking',
    from: deployer,
    log: true,
  });

  const data = new Staking__factory().interface.encodeFunctionData('initialize', []);

  await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxy',
    from: deployer,
    log: true,
    args: [stakingLogic.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['StakingContract'];
deploy.dependencies = ['ProxyAdmin', 'SortingLibrary'];

export default deploy;
