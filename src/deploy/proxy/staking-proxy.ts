import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { stakingConfig, generalRoninConf, roninchainNetworks } from '../../config';
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
    stakingConfig[network.name]!.minSecsToUndelegate,
    stakingConfig[network.name]!.secsForRevoking,
  ]);

  const deployment = await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce: generalRoninConf[network.name].stakingContract?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].stakingContract?.address);
};

deploy.tags = ['StakingProxy'];
deploy.dependencies = ['StakingLogic', 'CalculateAddresses', 'SlashIndicatorProxy'];

export default deploy;
