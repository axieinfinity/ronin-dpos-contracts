import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { Profile__factory } from '../../types';
import { Address } from 'hardhat-deploy/dist/types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('ProfileLogic');

  const nonce = generalRoninConf[network.name].profileContract?.nonce;
  // console.log(`Deploying ProfileProxy (nonce: ${nonce})...`);
  let governanceAdmin: Address | undefined = generalRoninConf[network.name]!.governanceAdmin?.address;

  if (!governanceAdmin) {
    const GADepl = await deployments.get('RoninGovernanceAdmin');
    governanceAdmin = GADepl.address;
  }

  const data = new Profile__factory().interface.encodeFunctionData('initialize', [
    generalRoninConf[network.name]!.stakingContract?.address,
    generalRoninConf[network.name]!.validatorContract?.address,
  ]);

  const deployment = await deploy('ProfileProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].profileContract?.address);
};

deploy.tags = ['ProfileProxy'];
deploy.dependencies = ['ProfileLogic', '_HelperDposCalculate', 'RoninValidatorSetProxy'];

export default deploy;
