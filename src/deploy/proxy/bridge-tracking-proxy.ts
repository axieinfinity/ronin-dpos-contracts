import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { BridgeTracking__factory } from '../../types';
import { Address } from 'hardhat-deploy/dist/types';
import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('BridgeTrackingLogic');
  let validatorContractAddress: Address;
  if (network.name == Network.Hardhat) {
    validatorContractAddress = generalRoninConf[network.name]!.validatorContract?.address!;
  } else {
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContractAddress = validatorContractDeployment.address;
  }

  const data = new BridgeTracking__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.bridgeContract,
    validatorContractAddress,
    generalRoninConf[network.name]!.startedAtBlock,
  ]);

  const deployment = await deploy('BridgeTrackingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.bridgeManagerContract?.address, data],
    nonce: generalRoninConf[network.name].bridgeTrackingContract?.nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].bridgeTrackingContract?.address);
};

deploy.tags = ['BridgeTrackingProxy'];
deploy.dependencies = ['BridgeTrackingLogic', '_HelperBridgeCalculate'];

export default deploy;
