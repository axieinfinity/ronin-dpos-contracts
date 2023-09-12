import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { Address } from 'hardhat-deploy/dist/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('ProfileLogic');

  const nonce = undefined;
  // console.log(`Deploying ProfileProxy (nonce: ${nonce})...`);
  let governanceAdmin: Address | undefined = generalRoninConf[network.name]!.governanceAdmin?.address;

  if (!governanceAdmin) {
    const GADepl = await deployments.get('RoninGovernanceAdmin');
    governanceAdmin = GADepl.address;
  }

  await deploy('ProfileProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, governanceAdmin, []],
  });
};

deploy.tags = ['ProfileProxy'];
deploy.dependencies = ['ProfileLogic'];

export default deploy;
