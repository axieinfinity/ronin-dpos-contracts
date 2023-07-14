import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { bridgeManagerConf } from '../configs/bridge-manager';
import { verifyAddress } from '../script/verify-address';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy('RoninBridgeManager', {
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      bridgeManagerConf[network.name]?.expiryDuration,
      generalRoninConf[network.name].bridgeContract,
      bridgeManagerConf[network.name]?.callbackRegisters,
      bridgeManagerConf[network.name]?.operators,
      bridgeManagerConf[network.name]?.governors,
      bridgeManagerConf[network.name]?.weights,
    ],
    nonce: generalRoninConf[network.name].bridgeManagerContract?.nonce,
  });

  verifyAddress(deployment.address, generalRoninConf[network.name].bridgeManagerContract?.address);
};

deploy.tags = ['RoninBridgeManager'];
deploy.dependencies = ['CalculateAddresses', 'BridgeRewardProxy'];

export default deploy;
