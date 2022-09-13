import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('StakingVestingLogic', {
    contract: 'StakingVesting',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['StakingVestingLogic'];
deploy.dependencies = ['ProxyAdmin'];

export default deploy;
