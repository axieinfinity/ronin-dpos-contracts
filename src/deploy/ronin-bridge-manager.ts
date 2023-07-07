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
  console.log(
    bridgeManagerConf[network.name]?.numerator,
    bridgeManagerConf[network.name]?.denominator,
    generalRoninConf[network.name].roninChainId,
    generalRoninConf[network.name].governanceAdmin,
    generalRoninConf[network.name].bridgeContract
  );

  await deploy('RoninBridgeManager', {
    contract: 'RoninBridgeManager',
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      generalRoninConf[network.name].governanceAdmin?.address,
      generalRoninConf[network.name].bridgeContract,
      bridgeManagerConf[network.name]?.weights,
      bridgeManagerConf[network.name]?.operators,
      bridgeManagerConf[network.name]?.governors,
    ],
  });
};

deploy.tags = ['RoninBridgeManager'];

export default deploy;
