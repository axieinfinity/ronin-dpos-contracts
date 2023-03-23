import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { gatewayPauseEnforcerConf } from '../configs/gateway';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninGatewayPauseEnforcer', {
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

deploy.tags = ['RoninGatewayPauseEnforcer'];

export default deploy;
