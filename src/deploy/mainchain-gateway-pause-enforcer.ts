import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, mainchainNetworks } from '../configs/config';
import { gatewayPauseEnforcerConf } from '../configs/gateway';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MainchainGatewayPauseEnforcer', {
    contract: 'PauseEnforcer',
    from: deployer,
    log: true,
    args: [
      generalRoninConf[network.name].bridgeContract,
      gatewayPauseEnforcerConf[network.name]?.enforcerAdmin,
      gatewayPauseEnforcerConf[network.name]?.sentries,
    ],
  });
};

deploy.tags = ['MainchainGatewayPauseEnforcer'];

export default deploy;
