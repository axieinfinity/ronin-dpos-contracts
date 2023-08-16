import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';
import { DEFAULT_ADDRESS, Network } from '../../utils';

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

  const proxyDepl = await deployments.get('RoninValidatorSetProxy');
  const newImplDelp = await deployments.get('RoninValidatorSetLogic');

  const IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
  const prevImplRawBytes32 = await ethers.provider.getStorageAt(proxyDepl.address, IMPLEMENTATION_SLOT);
  const prevImplAddr = '0x' + prevImplRawBytes32.slice(26);

  console.info('Deploying RoninValidatorSetTimedMigrator...');
  console.info('  proxy    ', proxyDepl.address);
  console.info('  new impl ', newImplDelp.address);
  console.info('  prev impl', prevImplAddr);

  if (prevImplAddr == DEFAULT_ADDRESS) {
    console.error('Invalid prev impl');
    return;
  }

  await deploy('RoninValidatorSetTimedMigrator', {
    from: deployer,
    log: true,
    args: [proxyDepl.address, prevImplAddr, newImplDelp.address],
  });
};

deploy.tags = ['RoninValidatorSetTimedMigrator'];

export default deploy;
