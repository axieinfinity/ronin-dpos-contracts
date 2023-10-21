import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('ProfileLogic', {
    contract: 'Profile',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['ProfileLogic'];

export default deploy;
