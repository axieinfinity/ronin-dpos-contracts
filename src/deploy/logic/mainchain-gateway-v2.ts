import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { mainchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MainchainGatewayV2Logic', {
    contract: 'MainchainGatewayV2',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['MainchainGatewayV2Logic'];

export default deploy;
