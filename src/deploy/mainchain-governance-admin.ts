import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { mainchainGovernanceAdminConf, mainchainInitAddress, mainchainNetworks } from '../config';
import { verifyAddress } from '../script/verify-address';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy('MainchainGovernanceAdmin', {
    from: deployer,
    log: true,
    args: [
      mainchainGovernanceAdminConf[network.name]?.roleSetter,
      mainchainInitAddress[network.name].roninTrustedOrganizationContract?.address,
      mainchainGovernanceAdminConf[network.name]?.bridgeContract,
      mainchainGovernanceAdminConf[network.name]?.relayers,
    ],
    nonce: mainchainInitAddress[network.name].governanceAdmin?.nonce,
  });
  verifyAddress(deployment.address, mainchainInitAddress[network.name].governanceAdmin?.address);
};

deploy.tags = ['MainchainGovernanceAdmin'];
deploy.dependencies = ['RoninValidatorSetProxy'];

export default deploy;
