import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalMainchainConf, mainchainNetworks } from '../../configs/config';
import { gatewayPauseEnforcerConf } from '../../configs/gateway';
import { PauseEnforcer__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('MainchainGatewayPauseEnforcerLogic');
  const GAContract = await deployments.get('MainchainGovernanceAdmin');

  const data = new PauseEnforcer__factory().interface.encodeFunctionData('initialize', [
    generalMainchainConf[network.name].bridgeContract,
    gatewayPauseEnforcerConf[network.name]?.enforcerAdmin,
    gatewayPauseEnforcerConf[network.name]?.sentries,
  ]);

  await deploy('MainchainGatewayPauseEnforcerProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, GAContract.address, data],
  });
};

deploy.tags = ['MainchainGatewayPauseEnforcerProxy'];
deploy.dependencies = ['MainchainGatewayPauseEnforcerLogic'];

export default deploy;
