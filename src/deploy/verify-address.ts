import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { initAddress } from '../config';

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  const MaintenanceContract = await deployments.get('MaintenanceProxy');
  const stakingVestingContract = await deployments.get('StakingVestingProxy');
  const slashIndicatorContract = await deployments.get('SlashIndicatorProxy');
  const stakingContract = await deployments.get('StakingProxy');
  const validatorContract = await deployments.get('RoninValidatorSetProxy');

  if (initAddress[network.name].maintenanceContract?.toLowerCase() != MaintenanceContract.address.toLowerCase()) {
    throw Error(
      `invalid address for indicator, expected=${initAddress[
        network.name
      ].maintenanceContract?.toLowerCase()}, actual=${MaintenanceContract.address.toLowerCase()}`
    );
  }
  if (initAddress[network.name].slashIndicatorContract?.toLowerCase() != slashIndicatorContract.address.toLowerCase()) {
    throw Error(
      `invalid address for slashIndicator, expected=${initAddress[
        network.name
      ].slashIndicatorContract?.toLowerCase()}, actual=${slashIndicatorContract.address.toLowerCase()}`
    );
  }
  if (initAddress[network.name].stakingVestingContract?.toLowerCase() != stakingVestingContract.address.toLowerCase()) {
    throw Error(
      `invalid address for stakingVestingContract, expected=${initAddress[
        network.name
      ].stakingVestingContract?.toLowerCase()}, actual=${stakingVestingContract.address.toLowerCase()}`
    );
  }
  if (initAddress[network.name].stakingContract?.toLowerCase() != stakingContract.address.toLowerCase()) {
    throw Error(
      `invalid address for stakingContract, expected=${initAddress[
        network.name
      ].stakingContract?.toLowerCase()}, actual=${stakingContract.address.toLowerCase()}`
    );
  }
  if (initAddress[network.name].validatorContract?.toLowerCase() != validatorContract.address.toLowerCase()) {
    throw Error(
      `invalid address for validatorContract, expected=${initAddress[
        network.name
      ].validatorContract?.toLowerCase()}, actual=${validatorContract.address.toLowerCase()}`
    );
  }
  console.log('All checks are done');
};

deploy.tags = ['VerifyAddress'];
deploy.dependencies = [
  'ProxyAdmin',
  'StakingProxy',
  'SlashIndicatorProxy',
  'StakingVestingProxy',
  'RoninValidatorSetProxy',
];

export default deploy;
