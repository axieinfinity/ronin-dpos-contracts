import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { initAddress } from '../config';

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  const indicator = await deployments.get('SlashIndicatorProxy');
  const stakingContract = await deployments.get('DPoStakingProxy');
  const validatorContract = await deployments.get('RoninValidatorSetProxy');

  if (initAddress[network.name].slashIndicator?.toLowerCase() != indicator.address.toLowerCase()) {
    throw Error(
      `invalid address for indicator, expected=${initAddress[
        network.name
      ].slashIndicator?.toLowerCase()}, actual=${indicator.address.toLowerCase()}`
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
deploy.dependencies = ['ProxyAdmin', 'DPoStakingProxy', 'SlashIndicatorProxy', 'RoninValidatorSetProxy'];

export default deploy;
