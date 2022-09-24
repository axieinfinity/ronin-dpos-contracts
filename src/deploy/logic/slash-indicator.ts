import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SlashIndicatorLogic', {
    contract: 'SlashIndicator',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['SlashIndicatorLogic'];

export default deploy;
