import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks, generalRoninConf, governanceAdminConf } from '../config';
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
      generalRoninConf[network.name].bridgeContract,
      governanceAdminConf[network.name]?.proposalExpiryDuration,
    ],
    nonce: generalRoninConf[network.name].governanceAdmin?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].governanceAdmin?.address);
};

deploy.tags = ['RoninGovernanceAdmin'];
deploy.dependencies = ['CalculateAddresses'];

export default deploy;
