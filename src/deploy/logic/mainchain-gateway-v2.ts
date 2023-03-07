import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (![Network.Local.toString()].includes(network.name!)) {
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
