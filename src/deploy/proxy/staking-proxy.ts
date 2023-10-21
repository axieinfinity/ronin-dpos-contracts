import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { stakingConfig, generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { Staking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('StakingLogic');

  const data = new Staking__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.validatorContract?.address,
    stakingConfig[network.name]!.minValidatorStakingAmount,
    stakingConfig[network.name]!.maxCommissionRate,
    stakingConfig[network.name]!.cooldownSecsToUndelegate,
    stakingConfig[network.name]!.waitingSecsToRevoke,
  ]);

  const nonce = generalRoninConf[network.name].stakingContract?.nonce;
  // console.log(`Deploying StakingProxy (nonce: ${nonce})...`);

  const deployment = await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].stakingContract?.address);
};

deploy.tags = ['StakingProxy'];
deploy.dependencies = ['StakingLogic', '_HelperDposCalculate', 'SlashIndicatorProxy'];

export default deploy;
