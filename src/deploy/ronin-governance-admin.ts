import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninGovernanceAdminConf, roninchainNetworks, generalRoninConf } from '../config';
import { verifyAddress } from '../script/verify-address';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy('RoninGovernanceAdmin', {
    from: deployer,
    log: true,
    args: [
      generalRoninConf[network.name].roninTrustedOrganizationContract?.address,
      roninGovernanceAdminConf[network.name]?.bridgeContract,
    ],
    nonce: generalRoninConf[network.name].governanceAdmin?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].governanceAdmin?.address);
};

deploy.tags = ['RoninGovernanceAdmin'];
deploy.dependencies = ['CalculateAddresses'];

export default deploy;
