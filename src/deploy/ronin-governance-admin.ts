import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks, generalRoninConf, roninGovernanceAdminConf } from '../configs/config';
import { verifyAddress } from '../script/verify-address';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let nonce = await ethers.provider.getTransactionCount(deployer);

  console.log('deploy abc');
  console.log('nonce', nonce);

  const deployment = await deploy('RoninGovernanceAdmin', {
    from: deployer,
    log: true,
    args: [
      generalRoninConf[network.name].roninChainId,
      generalRoninConf[network.name].roninTrustedOrganizationContract?.address,
      generalRoninConf[network.name].validatorContract?.address,
      roninGovernanceAdminConf[network.name]?.proposalExpiryDuration,
    ],
    nonce: generalRoninConf[network.name].governanceAdmin?.nonce,
  });

  console.log('deploy abc failed');
  verifyAddress(deployment.address, generalRoninConf[network.name].governanceAdmin?.address);
};

deploy.tags = ['RoninGovernanceAdmin'];
deploy.dependencies = ['CalculateAddresses'];

export default deploy;
