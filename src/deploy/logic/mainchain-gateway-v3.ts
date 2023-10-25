import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { mainchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MainchainGatewayV3Logic', {
    contract: 'MainchainGatewayV3',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['MainchainGatewayV3Logic'];

export default deploy;
