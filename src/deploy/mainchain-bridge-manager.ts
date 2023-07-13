import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalMainchainConf, generalRoninConf, mainchainNetworks } from '../configs/config';
import { bridgeManagerConf } from '../configs/bridge-manager';
import { verifyAddress } from '../script/verify-address';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let nonce = await ethers.provider.getTransactionCount(deployer);

  const deployment = await deploy('MainchainBridgeManager', {
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      generalRoninConf[network.name].bridgeContract,
      bridgeManagerConf[network.name]?.operators,
      bridgeManagerConf[network.name]?.governors,
      bridgeManagerConf[network.name]?.weights,
    ],
    nonce: generalMainchainConf[network.name].bridgeManagerContract?.nonce,
  });

  verifyAddress(deployment.address, generalMainchainConf[network.name].bridgeManagerContract?.address);
};

deploy.tags = ['MainchainBridgeManager'];

// Trick: Leaving 'BridgeTrackingProxy', 'RoninBridgeManager' here to make sure mainchain's contracts will be deployed
// after the ronin's ones on Hardhat network. This will not cause a redundant deployment of Ronin's contract on the
// mainchain, due to check of network at the beginning of each file.
deploy.dependencies = ['BridgeTrackingProxy', 'RoninBridgeManager', 'CalculateAddresses'];

export default deploy;
