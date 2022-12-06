import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninValidatorSetConf, generalRoninConf, roninchainNetworks } from '../../config';
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
    generalRoninConf[network.name]!.slashIndicatorContract?.address,
    generalRoninConf[network.name]!.stakingContract?.address,
    generalRoninConf[network.name]!.stakingVestingContract?.address,
    generalRoninConf[network.name]!.maintenanceContract?.address,
    generalRoninConf[network.name]!.roninTrustedOrganizationContract?.address,
    generalRoninConf[network.name]!.bridgeTrackingContract?.address,
    roninValidatorSetConf[network.name]!.maxValidatorNumber,
    roninValidatorSetConf[network.name]!.maxValidatorCandidate,
    roninValidatorSetConf[network.name]!.maxPrioritizedValidatorNumber,
    roninValidatorSetConf[network.name]!.minEffectiveDaysOnwards,
    roninValidatorSetConf[network.name]!.numberOfBlocksInEpoch,
  ]);

  const deployment = await deploy('RoninValidatorSetProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce: generalRoninConf[network.name].validatorContract?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].validatorContract?.address);
};

deploy.tags = ['RoninValidatorSetProxy'];
deploy.dependencies = ['RoninValidatorSetLogic', 'CalculateAddresses', 'StakingProxy'];

export default deploy;
