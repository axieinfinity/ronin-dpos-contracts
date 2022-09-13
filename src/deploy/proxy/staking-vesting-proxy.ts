import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { initAddress, stakingVestingConfig } from '../../config';
import { StakingVesting__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('StakingVestingLogic');

  const data = new StakingVesting__factory().interface.encodeFunctionData('initialize', [
    stakingVestingConfig[network.name]!.bonusPerBlock,
    initAddress[network.name]!.validatorContract,
  ]);

  await deploy('StakingVestingProxy', {
    contract: 'TransparentUpgradeableProxy',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
    value: stakingVestingConfig[network.name]!.topupAmount,
  });
};

deploy.tags = ['StakingVestingProxy'];
deploy.dependencies = ['ProxyAdmin', 'RoninValidatorSetLogic', 'SlashIndicatorProxy', 'StakingProxy'];

export default deploy;
