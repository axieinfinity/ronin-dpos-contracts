import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { gatewayAccountSet, namedAddresses } from '../../configs/addresses';

import { generalMainchainConf, mainchainNetworks } from '../../configs/config';
import { GatewayThreshold, gatewayThreshold, mainchainMappedToken, roninChainId } from '../../configs/gateway';
import { verifyAddress } from '../../script/verify-address';
import { MainchainGatewayV3__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('MainchainGatewayV3Logic');

  const weth = namedAddresses['weth'][network.name];
  const gatewayRoleSetter = namedAddresses['gatewayRoleSetter'][network.name];
  const withdrawalUnlockers = gatewayAccountSet['withdrawalUnlockers'][network.name];
  const { numerator, denominator, highTierVoteWeightNumerator } = gatewayThreshold[network.name]! as GatewayThreshold;
  const {
    mainchainTokens,
    roninTokens,
    standards,
    highTierThresholds,
    lockedThresholds,
    unlockFeePercentages,
    dailyWithdrawalLimits,
  } = mainchainMappedToken[network.name]!;

  const data = new MainchainGatewayV3__factory().interface.encodeFunctionData('initialize', [
    gatewayRoleSetter,
    weth,
    roninChainId[network.name],
    numerator,
    highTierVoteWeightNumerator,
    denominator,
    [mainchainTokens, roninTokens, withdrawalUnlockers],
    [highTierThresholds, lockedThresholds, unlockFeePercentages, dailyWithdrawalLimits],
    standards,
  ]);

  const deployment = await deploy('MainchainGatewayV3Proxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalMainchainConf[network.name]!.governanceAdmin?.address, data],
  });

  verifyAddress(deployment.address, generalMainchainConf[network.name].bridgeContract);
};

deploy.tags = ['MainchainGatewayV3Proxy'];
deploy.dependencies = ['MainchainGatewayV3Logic', '_HelperBridgeCalculate'];

export default deploy;
