import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, mainchainNetworks } from '../configs/config';
import { roninChainId } from '../configs/gateway';
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
      roninChainId[network.name],
      bridgeManagerConf[network.name]?.expiryDuration,
      generalRoninConf[network.name].governanceAdmin,
      generalRoninConf[network.name].bridgeContract,
    ],
  });
};

deploy.tags = ['MainchainBridgeManager'];

export default deploy;
