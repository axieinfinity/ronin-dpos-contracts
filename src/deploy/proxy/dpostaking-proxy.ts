import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { stakingConfig, initAddress } from '../../config';
import { DPoStaking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('DPoStakingLogic');

  const data = new DPoStaking__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    initAddress[network.name]!.governanceAdmin,
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
deploy.dependencies = ['ProxyAdmin', 'DPoStakingLogic', 'SlashIndicatorProxy'];

export default deploy;
