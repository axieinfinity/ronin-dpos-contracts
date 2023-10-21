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
      bridgeTrackingContract: calculateAddress(deployer, nonce++),
      bridgeSlashContract: calculateAddress(deployer, nonce++),
      bridgeRewardContract: calculateAddress(deployer, nonce++),
      bridgeManagerContract: calculateAddress(deployer, nonce++),
    };
  }

  if (mainchainNetworks.includes(network.name!)) {
    generalMainchainConf[network.name] = {
      ...generalMainchainConf[network.name],
      bridgeManagerContract: calculateAddress(deployer, nonce++),
    };
  }

  // Only for local
  if ([Network.Local.toString()].includes(network.name)) {
    generalMainchainConf[network.name].bridgeContract = calculateAddress(deployer, nonce++).address;
  }
};

deploy.tags = ['_HelperBridgeCalculate'];
deploy.dependencies = [
  'BridgeTrackingLogic',
  'BridgeSlashLogic',
  'BridgeRewardLogic',
  'MainchainGatewayV3Logic',
  'RoninGatewayV3Logic',
];

export default deploy;
