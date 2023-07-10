import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { roninChainId } from '../configs/gateway';
import { bridgeManagerConf } from '../configs/bridge-manager';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninBridgeManager', {
    contract: 'RoninBridgeManager',
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      bridgeManagerConf[network.name]?.expiryDuration,
      generalRoninConf[network.name].bridgeContract,
      bridgeManagerConf[network.name]?.operators,
      bridgeManagerConf[network.name]?.governors,
      bridgeManagerConf[network.name]?.weights,
    ],
  });
};

deploy.tags = ['RoninBridgeManager'];

export default deploy;
