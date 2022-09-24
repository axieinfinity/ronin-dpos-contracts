import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('StakingLogic', {
    contract: 'Staking',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['StakingLogic'];

export default deploy;
