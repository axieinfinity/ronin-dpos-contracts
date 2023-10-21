import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninValidatorSetConf, generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { RoninValidatorSet__factory } from '../../types';
import { DEFAULT_ADDRESS } from '../../utils';

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
    DEFAULT_ADDRESS, // generalRoninConf[network.name]!.bridgeTrackingContract?.address,
    roninValidatorSetConf[network.name]!.maxValidatorNumber,
    roninValidatorSetConf[network.name]!.maxValidatorCandidate,
    roninValidatorSetConf[network.name]!.maxPrioritizedValidatorNumber,
    roninValidatorSetConf[network.name]!.minEffectiveDaysOnwards,
    roninValidatorSetConf[network.name]!.numberOfBlocksInEpoch,
    [
      roninValidatorSetConf[network.name]!.emergencyExitLockedAmount,
      roninValidatorSetConf[network.name]!.emergencyExpiryDuration,
    ],
  ]);

  const nonce = generalRoninConf[network.name].validatorContract?.nonce;
  // console.log(`Deploying RoninValidatorSetProxy (nonce: ${nonce})...`);

  const deployment = await deploy('RoninValidatorSetProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].validatorContract?.address);
};

deploy.tags = ['RoninValidatorSetProxy'];
deploy.dependencies = ['RoninValidatorSetLogic', '_HelperDposCalculate', 'StakingProxy'];

export default deploy;
