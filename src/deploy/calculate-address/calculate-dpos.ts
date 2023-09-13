import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks, mainchainNetworks, generalMainchainConf } from '../../configs/config';
import { Network } from '../../utils';
import { calculateAddress } from './helper';

const deploy = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();
  let nonce = await ethers.provider.getTransactionCount(deployer);

  if (roninchainNetworks.includes(network.name!)) {
    generalRoninConf[network.name] = {
      ...generalRoninConf[network.name],
      governanceAdmin: calculateAddress(deployer, nonce++),
      roninTrustedOrganizationContract: calculateAddress(deployer, nonce++),
      maintenanceContract: calculateAddress(deployer, nonce++),
      stakingVestingContract: calculateAddress(deployer, nonce++),
      slashIndicatorContract: calculateAddress(deployer, nonce++),
      stakingContract: calculateAddress(deployer, nonce++),
      validatorContract: calculateAddress(deployer, nonce++),
      profileContract: calculateAddress(deployer, nonce++),
    };
  }
};

deploy.tags = ['_HelperDposCalculate'];
deploy.dependencies = [
  'MaintenanceLogic',
  'StakingVestingLogic',
  'SlashIndicatorLogic',
  'StakingLogic',
  'RoninValidatorSetLogic',
  'RoninTrustedOrganizationLogic',
  'ProfileLogic',
];

export default deploy;
