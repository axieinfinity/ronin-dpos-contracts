import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { BridgeSlash__factory } from '../../types';
import { Address } from 'hardhat-deploy/dist/types';
import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('BridgeSlashLogic');
  let validatorContractAddress: Address;
  if (network.name == Network.Hardhat) {
    validatorContractAddress = generalRoninConf[network.name]!.validatorContract?.address!;
  } else {
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContractAddress = validatorContractDeployment.address;
  }

  const data = new BridgeSlash__factory().interface.encodeFunctionData('initialize', [
    validatorContractAddress,
    generalRoninConf[network.name]!.bridgeManagerContract?.address,
    generalRoninConf[network.name]!.bridgeTrackingContract?.address,
  ]);

  const deployment = await deploy('BridgeSlashProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.bridgeManagerContract?.address, data],
    nonce: generalRoninConf[network.name].bridgeSlashContract?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].bridgeSlashContract?.address);
};

deploy.tags = ['BridgeSlashProxy'];
deploy.dependencies = ['BridgeSlashLogic', '_HelperBridgeCalculate', 'BridgeTrackingProxy'];

export default deploy;
