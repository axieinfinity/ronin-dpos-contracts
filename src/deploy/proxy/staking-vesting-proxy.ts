import { BigNumber } from 'ethers';
import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninInitAddress, roninchainNetworks, stakingVestingConfig } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { StakingVesting__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('StakingVestingLogic');

  const data = new StakingVesting__factory().interface.encodeFunctionData('initialize', [
    roninInitAddress[network.name]!.validatorContract?.address,
    stakingVestingConfig[network.name]!.bonusPerBlock,
  ]);

  const deployment = await deploy('StakingVestingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, roninInitAddress[network.name]!.governanceAdmin?.address, data],
    value: BigNumber.from(stakingVestingConfig[network.name]!.topupAmount),
    nonce: roninInitAddress[network.name].stakingVestingContract?.nonce,
  });
  verifyAddress(deployment.address, roninInitAddress[network.name].stakingVestingContract?.address);
};

deploy.tags = ['StakingVestingProxy'];
deploy.dependencies = ['StakingVestingLogic', 'CalculateAddresses', 'MaintenanceProxy'];

export default deploy;
