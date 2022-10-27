import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('BridgeTrackingLogic', {
    contract: 'BridgeTracking',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['BridgeTrackingLogic'];

export default deploy;
