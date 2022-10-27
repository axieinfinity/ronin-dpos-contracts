import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks, mainchainNetworks, generalMainchainConf } from '../config';

const calculateAddress = (from: string, nonce: number) => ({
  nonce,
  address: ethers.utils.getContractAddress({ from, nonce }),
});

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
      bridgeTrackingContract: calculateAddress(deployer, nonce++),
    };
  }

  if (mainchainNetworks.includes(network.name!)) {
    generalMainchainConf[network.name] = {
      ...generalMainchainConf[network.name],
      governanceAdmin: calculateAddress(deployer, nonce++),
      roninTrustedOrganizationContract: calculateAddress(deployer, nonce++),
    };
  }
};

deploy.tags = ['CalculateAddresses'];
deploy.dependencies = [
  'MaintenanceLogic',
  'StakingVestingLogic',
  'SlashIndicatorLogic',
  'StakingLogic',
  'RoninValidatorSetLogic',
  'RoninTrustedOrganizationLogic',
  'BridgeTrackingLogic',
];

export default deploy;
