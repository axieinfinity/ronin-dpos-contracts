import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { stakingConfig, initAddress, roninchainNetworks } from '../../config';
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
    initAddress[network.name]!.validatorContract?.address,
    stakingConfig[network.name]!.minValidatorBalance,
  ]);

  const deployment = await deploy('StakingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
    nonce: initAddress[network.name].stakingContract?.nonce,
  });
  verifyAddress(deployment.address, initAddress[network.name].stakingContract?.address);
};

deploy.tags = ['StakingProxy'];
deploy.dependencies = ['StakingLogic', 'CalculateAddresses', 'SlashIndicatorProxy'];

export default deploy;
