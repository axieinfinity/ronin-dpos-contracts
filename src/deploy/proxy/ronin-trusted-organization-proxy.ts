import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninTrustedOrganizationConf, initAddress, allNetworks } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { RoninTrustedOrganization__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!allNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('RoninTrustedOrganizationLogic');

  const data = new RoninTrustedOrganization__factory().interface.encodeFunctionData('initialize', [
    roninTrustedOrganizationConf[network.name]!.trustedOrganization,
  ]);

  const deployment = await deploy('RoninTrustedOrganizationProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
  });
  initAddress[network.name].roninTrustedOrganizationContract = { address: deployment.address };
};

deploy.tags = ['RoninTrustedOrganizationProxy'];
deploy.dependencies = ['RoninTrustedOrganizationLogic'];

export default deploy;
