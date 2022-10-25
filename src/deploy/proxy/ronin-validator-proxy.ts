import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninValidatorSetConf, roninInitAddress, roninchainNetworks } from '../../config';
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
    roninInitAddress[network.name]!.slashIndicatorContract?.address,
    roninInitAddress[network.name]!.stakingContract?.address,
    roninInitAddress[network.name]!.stakingVestingContract?.address,
    roninInitAddress[network.name]!.maintenanceContract?.address,
    roninInitAddress[network.name]!.roninTrustedOrganizationContract?.address,
    roninValidatorSetConf[network.name]!.maxValidatorNumber,
    roninValidatorSetConf[network.name]!.maxValidatorCandidate,
    roninValidatorSetConf[network.name]!.maxPrioritizedValidatorNumber,
    roninValidatorSetConf[network.name]!.numberOfBlocksInEpoch,
  ]);

  const deployment = await deploy('RoninValidatorSetProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, roninInitAddress[network.name]!.governanceAdmin?.address, data],
    nonce: roninInitAddress[network.name].validatorContract?.nonce,
  });
  verifyAddress(deployment.address, roninInitAddress[network.name].validatorContract?.address);
};

deploy.tags = ['RoninValidatorSetProxy'];
deploy.dependencies = ['RoninValidatorSetLogic', 'CalculateAddresses', 'StakingProxy'];

export default deploy;
