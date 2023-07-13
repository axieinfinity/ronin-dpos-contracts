import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('BridgeRewardLogic', {
    contract: 'BridgeReward',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['BridgeRewardLogic'];

export default deploy;
