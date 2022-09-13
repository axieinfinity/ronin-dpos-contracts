import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { roninValidatorSetConf, initAddress } from '../../config';
import { RoninValidatorSet__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const proxyAdmin = await deployments.get('ProxyAdmin');
  const logicContract = await deployments.get('RoninValidatorSetLogic');

  const data = new RoninValidatorSet__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.governanceAdmin,
    initAddress[network.name]!.slashIndicator,
    initAddress[network.name]!.stakingContract,
    initAddress[network.name]!.stakingVestingContract,
    roninValidatorSetConf[network.name]!.maxValidatorNumber,
    roninValidatorSetConf[network.name]!.numberOfBlocksInEpoch,
    roninValidatorSetConf[network.name]!.numberOfEpochsInPeriod,
  ]);

  await deploy('RoninValidatorSetProxy', {
    contract: 'TransparentUpgradeableProxy',
    from: deployer,
    log: true,
    args: [logicContract.address, proxyAdmin.address, data],
  });
};

deploy.tags = ['RoninValidatorSetProxy'];
deploy.dependencies = ['ProxyAdmin', 'RoninValidatorSetLogic', 'SlashIndicatorProxy', 'StakingProxy', 'StakingVestingProxy'];

export default deploy;
