import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { slashIndicatorConf, roninInitAddress, roninchainNetworks } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { SlashIndicator__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('SlashIndicatorLogic');

  const data = new SlashIndicator__factory().interface.encodeFunctionData('initialize', [
    roninInitAddress[network.name]!.validatorContract?.address,
    roninInitAddress[network.name]!.maintenanceContract?.address,
    roninInitAddress[network.name]!.roninTrustedOrganizationContract?.address,
    roninInitAddress[network.name]!.governanceAdmin?.address,
    [
      slashIndicatorConf[network.name]!.misdemeanorThreshold,
      slashIndicatorConf[network.name]!.felonyThreshold,
      slashIndicatorConf[network.name]!.bridgeVotingThreshold,
    ],
    [
      slashIndicatorConf[network.name]!.slashFelonyAmount,
      slashIndicatorConf[network.name]!.slashDoubleSignAmount,
      slashIndicatorConf[network.name]!.bridgeVotingSlashAmount,
    ],
    slashIndicatorConf[network.name]!.felonyJailBlocks,
    slashIndicatorConf[network.name]!.doubleSigningConstrainBlocks,
    [slashIndicatorConf[network.name]!.gainCreditScore, slashIndicatorConf[network.name]!.maxCreditScore],
    slashIndicatorConf[network.name]!.bailOutCostMultiplier,
  ]);

  const deployment = await deploy('SlashIndicatorProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, roninInitAddress[network.name]!.governanceAdmin?.address, data],
    nonce: roninInitAddress[network.name].slashIndicatorContract?.nonce,
  });
  verifyAddress(deployment.address, roninInitAddress[network.name].slashIndicatorContract?.address);
};

deploy.tags = ['SlashIndicatorProxy'];
deploy.dependencies = ['SlashIndicatorLogic', 'CalculateAddresses', 'StakingVestingProxy'];

export default deploy;
