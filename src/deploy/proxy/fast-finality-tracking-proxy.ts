import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { FastFinalityTracking__factory } from '../../types';
import { Address } from 'hardhat-deploy/dist/types';
import { Network } from '../../utils';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('FastFinalityTrackingLogic');

  let validatorContractAddress: Address;
  let governanceAdmin: Address;
  let nonce: number | undefined;
  if (network.name == Network.Hardhat) {
    nonce = generalRoninConf[network.name].fastFinalityTrackingContract?.nonce!;

    validatorContractAddress = generalRoninConf[network.name]!.validatorContract?.address!;
    governanceAdmin = generalRoninConf[network.name]!.governanceAdmin?.address!;
  } else {
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContractAddress = validatorContractDeployment.address;

    const GADepl = await deployments.get('RoninGovernanceAdmin');
    governanceAdmin = GADepl.address;
  }

  const data = new FastFinalityTracking__factory().interface.encodeFunctionData('initialize', [
    validatorContractAddress,
  ]);

  // console.log(`Deploying FastFinalityTrackingProxy (nonce: ${nonce})...`);

  const deployment = await deploy('FastFinalityTrackingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, governanceAdmin, data],
    nonce,
  });

  if (network.name == Network.Hardhat) {
    verifyAddress(deployment.address, generalRoninConf[network.name].fastFinalityTrackingContract?.address);
  }
};

deploy.tags = ['FastFinalityTrackingProxy'];
deploy.dependencies = ['FastFinalityTrackingLogic', '_HelperDposCalculate', 'RoninGovernanceAdmin'];

export default deploy;
