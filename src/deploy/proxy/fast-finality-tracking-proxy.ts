import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { FastFinalityTracking__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('FastFinalityTrackingLogic');

  const data = new FastFinalityTracking__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.validatorContract?.address,
  ]);

  const nonce = generalRoninConf[network.name].fastFinalityTrackingContract?.nonce;
  // console.log(`Deploying FastFinalityTrackingProxy (nonce: ${nonce})...`);

  const deployment = await deploy('FastFinalityTrackingProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].fastFinalityTrackingContract?.address);
};

deploy.tags = ['FastFinalityTrackingProxy'];
deploy.dependencies = ['FastFinalityTrackingLogic', '_HelperDposCalculate', 'RoninGovernanceAdmin'];

export default deploy;
