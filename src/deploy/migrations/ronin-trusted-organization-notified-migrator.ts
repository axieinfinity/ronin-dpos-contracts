import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';
import { DEFAULT_ADDRESS, Network, getImplementOfProxy } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  // No need to deploy on hardhat network, to not break fixture
  if (network.name === Network.Hardhat) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyDepl = await deployments.get('RoninTrustedOrganizationProxy');
  const newImplDelp = await deployments.get('RoninTrustedOrganizationLogic');

  const prevImplAddr = await getImplementOfProxy(proxyDepl.address);
  const roninValidatorAddr = await deployments.get('RoninValidatorSetProxy');

  console.info('Deploying RoninTrustedOrganizationNotifiedMigrator...');
  console.info('  proxy    ', proxyDepl.address);
  console.info('  new impl ', newImplDelp.address);
  console.info('  prev impl', prevImplAddr);
  console.info('  ronin validator set', roninValidatorAddr.address);

  if (prevImplAddr == DEFAULT_ADDRESS) {
    console.error('Invalid prev impl');
    return;
  }

  const deployment = await deploy('RoninTrustedOrganizationNotifiedMigrator', {
    contract: 'NotifiedMigrator',
    from: deployer,
    log: true,
    args: [proxyDepl.address, prevImplAddr, newImplDelp.address, roninValidatorAddr.address],
  });
};

deploy.tags = ['RoninTrustedOrganizationNotifiedMigrator', 'MigratorBridgeDetachV0_6'];
deploy.dependencies = ['RoninTrustedOrganizationProxy'];

export default deploy;
