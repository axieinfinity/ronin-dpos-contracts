import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { Profile__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('ProfileLogic');

  const data = new Profile__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.stakingContract?.address,
    generalRoninConf[network.name]!.validatorContract?.address,
  ]);

  const deployment = await deploy('ProfileProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
  });
};

deploy.tags = ['ProfileProxy'];
deploy.dependencies = ['ProfileLogic'];

export default deploy;
