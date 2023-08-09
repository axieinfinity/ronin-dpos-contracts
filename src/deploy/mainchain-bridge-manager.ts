import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalMainchainConf, generalRoninConf, mainchainNetworks } from '../configs/config';
import { TargetOptionStruct, bridgeManagerConf } from '../configs/bridge-manager';
import { verifyAddress } from '../script/verify-address';
import { TargetOption } from '../script/proposal';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const targets: TargetOptionStruct[] = [
    {
      option: TargetOption.GatewayContract,
      target: generalMainchainConf[network.name].bridgeContract,
    },
  ];

  const deployment = await deploy('MainchainBridgeManager', {
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalMainchainConf[network.name].roninChainId,
      generalMainchainConf[network.name].bridgeContract,
      [],
      bridgeManagerConf[network.name]?.members?.map((_) => _.operator),
      bridgeManagerConf[network.name]?.members?.map((_) => _.governor),
      bridgeManagerConf[network.name]?.members?.map((_) => _.weight),
      targets.map((_) => _.option),
      targets.map((_) => _.target),
    ],
    nonce: generalMainchainConf[network.name].bridgeManagerContract?.nonce,
  });

  verifyAddress(deployment.address, generalMainchainConf[network.name].bridgeManagerContract?.address);
};

deploy.tags = ['MainchainBridgeManager'];

// Trick: Leaving 'BridgeTrackingProxy', 'RoninBridgeManager' here to make sure mainchain's contracts will be deployed
// after the ronin's ones on Hardhat network. This will not cause a redundant deployment of Ronin's contract on the
// mainchain, due to check of network at the beginning of each file.
deploy.dependencies = ['BridgeTrackingProxy', 'RoninBridgeManager', '_HelperBridgeCalculate'];

export default deploy;
