import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { TargetOptionStruct, bridgeManagerConf } from '../configs/bridge-manager';
import { verifyAddress } from '../script/verify-address';
import { TargetOption } from '../script/proposal';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const targets: TargetOptionStruct[] = [
    {
      option: TargetOption.GatewayContract,
      target: generalRoninConf[network.name].bridgeContract,
    },
    {
      option: TargetOption.BridgeReward,
      target: generalRoninConf[network.name].bridgeRewardContract?.address!,
    },
    {
      option: TargetOption.BridgeSlash,
      target: generalRoninConf[network.name].bridgeSlashContract?.address!,
    },
  ];

  const deployment = await deploy('RoninBridgeManager', {
    from: deployer,
    log: true,
    args: [
      bridgeManagerConf[network.name]?.numerator,
      bridgeManagerConf[network.name]?.denominator,
      generalRoninConf[network.name].roninChainId,
      bridgeManagerConf[network.name]?.expiryDuration,
      generalRoninConf[network.name].bridgeContract,
      [generalRoninConf[network.name].bridgeSlashContract?.address],
      bridgeManagerConf[network.name]?.members?.map((_) => _.operator),
      bridgeManagerConf[network.name]?.members?.map((_) => _.governor),
      bridgeManagerConf[network.name]?.members?.map((_) => _.weight),
      targets.map((_) => _.option),
      targets.map((_) => _.target),
    ],
    nonce: generalRoninConf[network.name].bridgeManagerContract?.nonce,
  });

  verifyAddress(deployment.address, generalRoninConf[network.name].bridgeManagerContract?.address);
};

deploy.tags = ['RoninBridgeManager'];
deploy.dependencies = ['_HelperBridgeCalculate', 'BridgeRewardProxy'];

export default deploy;
