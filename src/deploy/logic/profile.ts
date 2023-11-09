import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';
import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let contractToDeploy;
  switch (network.name!) {
    case Network.Testnet:
      contractToDeploy = 'Profile_Testnet';
    case Network.Mainnet:
      contractToDeploy = 'Profile_Mainnet';
    default:
      contractToDeploy = 'Profile';
  }

  await deploy('ProfileLogic', {
    contract: contractToDeploy,
    from: deployer,
    log: true,
  });
};

deploy.tags = ['ProfileLogic'];

export default deploy;
