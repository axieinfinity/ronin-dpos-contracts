import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { mainchainGovernanceAdminConf, generalMainchainConf, mainchainNetworks } from '../configs/config';
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
      generalMainchainConf[network.name].roninChainId,
      mainchainGovernanceAdminConf[network.name]?.roleSetter,
      generalMainchainConf[network.name].roninTrustedOrganizationContract?.address,
      generalMainchainConf[network.name].bridgeContract,
      mainchainGovernanceAdminConf[network.name]?.relayers,
    ],
    nonce: generalMainchainConf[network.name].governanceAdmin?.nonce,
  });
  verifyAddress(deployment.address, generalMainchainConf[network.name].governanceAdmin?.address);
};

deploy.tags = ['MainchainGovernanceAdmin'];
deploy.dependencies = ['BridgeTrackingProxy'];

export default deploy;
