import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks, mainchainNetworks, generalMainchainConf } from '../configs/config';
import { Network } from '../utils';

const calculateAddress = (from: string, nonce: number) => ({
  nonce,
  address: ethers.utils.getContractAddress({ from, nonce }),
});

const deploy = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();
  let nonce = await ethers.provider.getTransactionCount(deployer);
  console.log('nonce', nonce);

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
      bridgeManagerContract: calculateAddress(deployer, nonce++),
    };
  }

  if (mainchainNetworks.includes(network.name!)) {
    generalMainchainConf[network.name] = {
      ...generalMainchainConf[network.name],
      bridgeManagerContract: calculateAddress(deployer, nonce++),
    };
  }

  console.log('OK');
  console.log('network name', network.name);
  console.log(generalRoninConf[network.name]);
  console.log(generalMainchainConf[network.name]);

  // Only for local
  if ([Network.Local.toString()].includes(network.name)) {
    generalMainchainConf[network.name].bridgeContract = calculateAddress(deployer, nonce++).address;
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
  'MainchainGatewayV2Logic',
  'RoninGatewayV2Logic',
];

export default deploy;
