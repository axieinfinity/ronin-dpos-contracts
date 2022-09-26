import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { stakingConfig, initAddress } from '../../config';
import { Staking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('StakingLogic');

  const data = new Staking__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    stakingConfig[network.name]!.minValidatorBalance,
  ]);

  await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
  });
};

deploy.tags = ['StakingProxy'];
deploy.dependencies = ['StakingLogic', 'SlashIndicatorProxy'];

export default deploy;
