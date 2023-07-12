import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, mainchainNetworks } from '../configs/config';
import { bridgeManagerConf } from '../configs/bridge-manager';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MainchainBridgeManager', {
    contract: 'MainchainBridgeManager',
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      generalRoninConf[network.name].bridgeContract,
      bridgeManagerConf[network.name]?.operators,
      bridgeManagerConf[network.name]?.governors,
      bridgeManagerConf[network.name]?.weights,
    ],
  });
};

deploy.tags = ['MainchainBridgeManager'];

export default deploy;
