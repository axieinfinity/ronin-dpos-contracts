import { network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks, vaultForwarderConf } from '../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const artifactName = 'VaultForwarder';

  let vaultConfigs = vaultForwarderConf[network.name]!;
  let targets: Address[] = [];
  let admin: Address = deployer;
  let moderator: Address = deployer;

  for (let vaultConf of vaultConfigs) {
    let deploymentName = [artifactName, vaultConf.vaultId].join('-');

    await deploy(deploymentName, {
      contract: artifactName,
      from: deployer,
      log: true,
      args: [
        // target
        vaultConf.targets ?? targets,
        // admin
        vaultConf.admin ?? admin,
        // moderator
        vaultConf.moderator ?? moderator,
      ],
    });
  }
};

deploy.tags = ['VaultForwarder'];

export default deploy;
