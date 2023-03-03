import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninValidatorSetLogic', {
    contract: 'RoninValidatorSet',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['RoninValidatorSetLogic'];

export default deploy;
