import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninGatewayV2Logic', {
    contract: 'RoninGatewayV2',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['RoninGatewayV2Logic'];

export default deploy;
