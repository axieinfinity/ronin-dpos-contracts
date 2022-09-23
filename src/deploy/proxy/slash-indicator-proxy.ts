import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { slashIndicatorConf, initAddress } from '../../config';
import { SlashIndicator__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('SlashIndicatorLogic');

  const data = new SlashIndicator__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.validatorContract,
    initAddress[network.name]!.maintenanceContract,
    slashIndicatorConf[network.name]!.misdemeanorThreshold,
    slashIndicatorConf[network.name]!.felonyThreshold,
    slashIndicatorConf[network.name]!.slashFelonyAmount,
    slashIndicatorConf[network.name]!.slashDoubleSignAmount,
    slashIndicatorConf[network.name]!.felonyJailBlocks,
  ]);

  await deploy('SlashIndicatorProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['SlashIndicatorProxy'];
deploy.dependencies = ['ProxyAdmin', 'SlashIndicatorLogic', 'StakingVestingProxy'];

export default deploy;
