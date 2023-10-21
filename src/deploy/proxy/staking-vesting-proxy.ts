import { BigNumber } from 'ethers';
import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks, stakingVestingConfig } from '../../configs/config';
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
    generalRoninConf[network.name]!.validatorContract?.address,
    stakingVestingConfig[network.name]!.blockProducerBonusPerBlock,
    stakingVestingConfig[network.name]!.bridgeOperatorBonusPerBlock,
  ]);

  const nonce = generalRoninConf[network.name].stakingVestingContract?.nonce;
  // console.log(`Deploying StakingVestingProxy (nonce: ${nonce})...`);

  const deployment = await deploy('StakingVestingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    value: BigNumber.from(stakingVestingConfig[network.name]!.topupAmount),
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].stakingVestingContract?.address);
};

deploy.tags = ['StakingVestingProxy'];
deploy.dependencies = ['StakingVestingLogic', '_HelperDposCalculate', 'MaintenanceProxy'];

export default deploy;
