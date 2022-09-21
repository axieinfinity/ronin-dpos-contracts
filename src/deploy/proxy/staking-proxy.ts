import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { stakingConfig, initAddress } from '../../config';
import { Staking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('StakingLogic');

  const data = new Staking__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    stakingConfig[network.name]!.minValidatorBalance,
  ]);

  await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxy',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['StakingProxy'];
deploy.dependencies = ['ProxyAdmin', 'StakingLogic', 'SlashIndicatorProxy'];

export default deploy;
