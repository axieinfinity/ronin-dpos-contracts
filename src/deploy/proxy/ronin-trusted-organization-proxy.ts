import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninTrustedOrganizationConf, generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { RoninTrustedOrganization__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('RoninTrustedOrganizationLogic');
  const data = new RoninTrustedOrganization__factory().interface.encodeFunctionData('initialize', [
    roninTrustedOrganizationConf[network.name]!.trustedOrganizations,
    roninTrustedOrganizationConf[network.name]!.numerator,
    roninTrustedOrganizationConf[network.name]!.denominator,
  ]);

  const nonce = undefined;
  // console.log(`Deploying RoninTrustedOrganizationProxy (nonce: ${nonce})...`);

  const deployment = await deploy('RoninTrustedOrganizationProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name].governanceAdmin?.address, data],
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].roninTrustedOrganizationContract?.address);
};

deploy.tags = ['RoninTrustedOrganizationProxy'];
deploy.dependencies = ['RoninTrustedOrganizationLogic', '_HelperDposCalculate', 'RoninGovernanceAdmin'];

export default deploy;
