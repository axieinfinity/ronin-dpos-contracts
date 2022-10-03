import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { allNetworks, initAddress, roninchainNetworks } from '../config';

const calculateAddress = (from: string, nonce: number) => ({
  nonce,
  address: ethers.utils.getContractAddress({ from, nonce }),
});

const deploy = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();
  let nonce = await ethers.provider.getTransactionCount(deployer);

  if (roninchainNetworks.includes(network.name!)) {
    initAddress[network.name].maintenanceContract = calculateAddress(deployer, nonce++);
    initAddress[network.name].stakingVestingContract = calculateAddress(deployer, nonce++);
    initAddress[network.name].slashIndicatorContract = calculateAddress(deployer, nonce++);
    initAddress[network.name].stakingContract = calculateAddress(deployer, nonce++);
    initAddress[network.name].validatorContract = calculateAddress(deployer, nonce++);
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
  'RoninTrustedOrganizationProxy',
];

export default deploy;
