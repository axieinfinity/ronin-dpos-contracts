import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { verifyAddress } from '../../script/verify-address';
import { Address } from 'hardhat-deploy/dist/types';
import { Network } from '../../utils';
import { Profile__factory } from '../../types';

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

  let validatorContractAddress: Address;
  if (network.name == Network.Hardhat) {
    validatorContractAddress = generalRoninConf[network.name]!.validatorContract?.address!;
  } else {
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContractAddress = validatorContractDeployment.address;
  }

  const data = new Profile__factory().interface.encodeFunctionData('initialize', [validatorContractAddress]);

  const deployment = await deploy('ProfileProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, governanceAdmin, data],
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].profileContract?.address);
};

deploy.tags = ['ProfileProxy'];
deploy.dependencies = ['ProfileLogic', '_HelperDposCalculate', 'RoninValidatorSetProxy'];

export default deploy;
