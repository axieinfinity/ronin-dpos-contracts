import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RoninValidatorSetLogic', {
    contract: 'RoninValidatorSet',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['RoninValidatorSetLogic'];
deploy.dependencies = ['ProxyAdmin'];

export default deploy;
