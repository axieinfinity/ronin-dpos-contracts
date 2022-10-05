import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninValidatorSetConf, initAddress, roninchainNetworks } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { RoninValidatorSet__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('RoninValidatorSetLogic');

  const data = new RoninValidatorSet__factory().interface.encodeFunctionData('initialize', [
    initAddress[network.name]!.slashIndicatorContract?.address,
    initAddress[network.name]!.stakingContract?.address,
    initAddress[network.name]!.stakingVestingContract?.address,
    initAddress[network.name]!.maintenanceContract?.address,
    initAddress[network.name]!.roninTrustedOrganizationContract?.address,
    roninValidatorSetConf[network.name]!.maxValidatorNumber,
    roninValidatorSetConf[network.name]!.maxValidatorCandidate,
    roninValidatorSetConf[network.name]!.maxPrioritizedValidatorNumber,
    roninValidatorSetConf[network.name]!.numberOfBlocksInEpoch,
    roninValidatorSetConf[network.name]!.numberOfEpochsInPeriod,
  ]);

  const deployment = await deploy('RoninValidatorSetProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, initAddress[network.name]!.governanceAdmin, data],
    nonce: initAddress[network.name].validatorContract?.nonce,
  });
  verifyAddress(deployment.address, initAddress[network.name].validatorContract?.address);
};

deploy.tags = ['RoninValidatorSetProxy'];
deploy.dependencies = ['RoninValidatorSetLogic', 'CalculateAddresses', 'StakingProxy'];

export default deploy;
