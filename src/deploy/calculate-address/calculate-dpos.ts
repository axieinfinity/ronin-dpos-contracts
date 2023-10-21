import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { calculateAddress } from './helper';

const deploy = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();
  let nonce = await ethers.provider.getTransactionCount(deployer);

  if (roninchainNetworks.includes(network.name!)) {
    generalRoninConf[network.name] = {
      ...generalRoninConf[network.name],
      governanceAdmin: calculateAddress(deployer, nonce++),
      fastFinalityTrackingContract: calculateAddress(deployer, nonce++),
      roninTrustedOrganizationContract: calculateAddress(deployer, nonce++),
      maintenanceContract: calculateAddress(deployer, nonce++),
      stakingVestingContract: calculateAddress(deployer, nonce++),
      slashIndicatorContract: calculateAddress(deployer, nonce++),
      stakingContract: calculateAddress(deployer, nonce++),
      validatorContract: calculateAddress(deployer, nonce++),
    };
  }

  // console.debug('Nonce calculation for deployments...');
  // console.table(generalRoninConf[network.name]);
};

deploy.tags = ['_HelperDposCalculate'];
deploy.dependencies = [
  'FastFinalityTrackingLogic',
  'MaintenanceLogic',
  'StakingVestingLogic',
  'SlashIndicatorLogic',
  'StakingLogic',
  'RoninValidatorSetLogic',
  'RoninTrustedOrganizationLogic',
];

export default deploy;
