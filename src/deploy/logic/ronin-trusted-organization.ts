import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { allNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!allNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninTrustedOrganizationLogic', {
    contract: 'RoninTrustedOrganization',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['RoninTrustedOrganizationLogic'];

export default deploy;
