import { ethers, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninchainNetworks } from '../../configs/config';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let nonce = await ethers.provider.getTransactionCount(deployer);

  await deploy('RoninGatewayV3Logic', {
    contract: 'RoninGatewayV3',
    from: deployer,
    log: true,
  });
};

deploy.tags = ['RoninGatewayV3Logic'];

export default deploy;
