import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { gatewayAccountSet, namedAddresses } from '../../configs/addresses';

import { roninchainNetworks } from '../../configs/config';
import { GatewayThreshold, gatewayThreshold, roninMappedToken } from '../../configs/gateway';
import { RoninGatewayV2__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  // const logicContract = await deployments.get('RoninGatewayV2Logic');
  const logicContractAddress = '0xF7460e5A14Ac8aC700aF4e564228a9FAff2E9C04';

  const gatewayRoleSetter = namedAddresses['gatewayRoleSetter'][network.name];
  const withdrawalMigrators = gatewayAccountSet['withdrawalMigrators'][network.name];
  const { numerator, denominator } = gatewayThreshold[network.name]! as GatewayThreshold;
  const { mainchainTokens, roninTokens, standards, minimumThresholds, chainIds } = roninMappedToken[network.name]!;

  const data = new RoninGatewayV2__factory().interface.encodeFunctionData('initialize', [
    gatewayRoleSetter,
    numerator,
    denominator,
    withdrawalMigrators,
    [roninTokens, mainchainTokens],
    [chainIds, minimumThresholds],
    standards,
  ]);

  const deployment = await deploy('RoninGatewayV2Proxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContractAddress, deployer, data],
  });

  const setValidatorData = new RoninGatewayV2__factory().interface.encodeFunctionData('setValidatorContract', [
    '0x262a3cab2bbb6fc414eb78e6755bf544b97dac01',
  ]);
  await execute('RoninGatewayV2Proxy', { from: deployer, log: true }, 'functionDelegateCall', setValidatorData);

  const setBridgeTracking = new RoninGatewayV2__factory().interface.encodeFunctionData('setBridgeTrackingContract', [
    '0xBf9e491df628A3ab6daacb7b288032C1f84db52C',
  ]);
  await execute('RoninGatewayV2Proxy', { from: deployer, log: true }, 'functionDelegateCall', setBridgeTracking);
};

deploy.tags = ['RoninGatewayV2Proxy'];

export default deploy;
