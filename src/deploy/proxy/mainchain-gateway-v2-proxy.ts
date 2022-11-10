import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalMainchainConf } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { MainchainGatewayV2__factory } from '../../types';
import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (![Network.Local.toString()].includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('MainchainGatewayV2Logic');

  const data = new MainchainGatewayV2__factory().interface.encodeFunctionData('initialize', [
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    0,
    0,
    0,
    1,
    [[], [], []],
    [[], [], [], []],
    [],
  ]);

  const deployment = await deploy('MainchainGatewayV2Proxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalMainchainConf[network.name]!.governanceAdmin?.address, data],
  });
  verifyAddress(deployment.address, generalMainchainConf[network.name].bridgeContract);
};

deploy.tags = ['MainchainGatewayV2Proxy'];
deploy.dependencies = ['MainchainGatewayV2Logic', 'CalculateAddresses', 'MainchainRoninTrustedOrganizationProxy'];

export default deploy;
