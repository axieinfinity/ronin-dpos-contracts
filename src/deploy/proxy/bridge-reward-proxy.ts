import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { BridgeReward__factory } from '../../types';
import { bridgeRewardConf } from '../../configs/bridge-manager';
import { BigNumber } from 'ethers';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('BridgeRewardLogic');

  const data = new BridgeReward__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.bridgeManagerContract?.address,
    generalRoninConf[network.name]!.bridgeTrackingContract?.address,
    generalRoninConf[network.name]!.bridgeSlashContract?.address,
    bridgeRewardConf[network.name]!.rewardPerPeriod,
  ]);

  const deployment = await deploy('BridgeRewardProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    value: BigNumber.from(bridgeRewardConf[network.name]!.topupAmount),
    nonce: generalRoninConf[network.name].bridgeRewardContract?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].bridgeRewardContract?.address);
};

deploy.tags = ['BridgeRewardProxy'];
deploy.dependencies = ['BridgeRewardLogic', 'CalculateAddresses', 'BridgeSlashProxy'];

export default deploy;
