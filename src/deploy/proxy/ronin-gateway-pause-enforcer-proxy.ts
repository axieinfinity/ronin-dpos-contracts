import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { gatewayPauseEnforcerConf } from '../../configs/gateway';
import { PauseEnforcer__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('RoninGatewayPauseEnforcerLogic');
  const GAContract = await deployments.get('RoninGovernanceAdmin');

  const data = new PauseEnforcer__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name].bridgeContract,
    gatewayPauseEnforcerConf[network.name]?.enforcerAdmin,
    gatewayPauseEnforcerConf[network.name]?.sentries,
  ]);

  await deploy('RoninGatewayPauseEnforcerProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, GAContract.address, data],
  });
};

deploy.tags = ['RoninGatewayPauseEnforcerProxy'];
deploy.dependencies = ['RoninGatewayPauseEnforcerLogic'];

export default deploy;
