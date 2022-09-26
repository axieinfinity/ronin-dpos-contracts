import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { initAddress } from '../config';

const deploy = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();
  let nonce = await ethers.provider.getTransactionCount(deployer);
  initAddress[network.name].maintenanceContract = ethers.utils.getContractAddress({
    from: deployer,
    nonce: nonce++,
  });
  initAddress[network.name].stakingVestingContract = ethers.utils.getContractAddress({
    from: deployer,
    nonce: nonce++,
  });
  initAddress[network.name].slashIndicatorContract = ethers.utils.getContractAddress({
    from: deployer,
    nonce: nonce++,
  });
  initAddress[network.name].stakingContract = ethers.utils.getContractAddress({ from: deployer, nonce: nonce++ });
  initAddress[network.name].validatorContract = ethers.utils.getContractAddress({ from: deployer, nonce: nonce++ });
};

deploy.tags = ['CalculateAddresses'];
deploy.dependencies = [
  'MaintenanceLogic',
  'StakingVestingLogic',
  'SlashIndicatorLogic',
  'StakingLogic',
  'RoninValidatorSetLogic',
];

export default deploy;
