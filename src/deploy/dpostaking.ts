import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { stakingConfig } from '../script/dpostaking';
import { DPoStaking__factory } from '../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('DPoStakingLogic');

  const data = new DPoStaking__factory().interface.encodeFunctionData('initialize', [
    stakingConfig[network.name]!.validatorContract,
    stakingConfig[network.name]!.governanceAdminContract,
    stakingConfig[network.name]!.maxValidatorCandidate,
    stakingConfig[network.name]!.minValidatorBalance,
  ]);

  await deploy('DPoStakingProxy', {
    contract: 'TransparentUpgradeableProxy',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['DPoStakingProxy'];
deploy.dependencies = ['ProxyAdmin', 'DPoStakingLogic'];

export default deploy;
