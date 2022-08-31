import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { Staking__factory } from '../types';
import { StakingLibraryAddresses } from '../types/factories/Staking__factory';

const deploy = async ({ getNamedAccounts, deployments}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  let { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const sortingLibrary = await deployments.get('SortingLibrary');
  const stakingLogic = await deploy('StakingLogic', {
    contract: 'Staking',
    from: deployer,
    log: true,
    libraries: {
      Sorting: sortingLibrary.address,
    },
  });

  const param: StakingLibraryAddresses = {
    ['contracts/libraries/Sorting.sol:Sorting']: sortingLibrary.address,
  };

  const data = new Staking__factory(param).interface.encodeFunctionData('initialize', []);

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
