import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { BridgeTracking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('ProfileLogic');

  await deploy('ProfileProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    // TODO: use this args when on production
    // args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, []],
    args: [logicContract.address, deployer, []],
  });
};

deploy.tags = ['ProfileProxy'];
deploy.dependencies = ['ProfileLogic'];

export default deploy;
