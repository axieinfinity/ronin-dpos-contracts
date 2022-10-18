import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninGovernanceAdminConf, roninchainNetworks, roninInitAddress } from '../config';
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
      roninInitAddress[network.name].roninTrustedOrganizationContract?.address,
      roninGovernanceAdminConf[network.name]?.bridgeContract,
    ],
    nonce: roninInitAddress[network.name].governanceAdmin?.nonce,
  });
  verifyAddress(deployment.address, roninInitAddress[network.name].governanceAdmin?.address);
};

deploy.tags = ['RoninGovernanceAdmin'];
deploy.dependencies = ['CalculateAddresses'];

export default deploy;
