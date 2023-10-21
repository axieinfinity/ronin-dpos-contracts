import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { slashIndicatorConf, generalRoninConf, roninchainNetworks } from '../../configs/config';
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
    generalRoninConf[network.name]!.validatorContract?.address,
    generalRoninConf[network.name]!.maintenanceContract?.address,
    generalRoninConf[network.name]!.roninTrustedOrganizationContract?.address,
    generalRoninConf[network.name]!.governanceAdmin?.address,
    [
      slashIndicatorConf[network.name]!.bridgeOperatorSlashing?.missingVotesRatioTier1,
      slashIndicatorConf[network.name]!.bridgeOperatorSlashing?.missingVotesRatioTier2,
      slashIndicatorConf[network.name]!.bridgeOperatorSlashing?.jailDurationForMissingVotesRatioTier2,
      slashIndicatorConf[network.name]!.bridgeOperatorSlashing?.skipBridgeOperatorSlashingThreshold,
    ],
    [
      slashIndicatorConf[network.name]!.bridgeVotingSlashing?.bridgeVotingThreshold,
      slashIndicatorConf[network.name]!.bridgeVotingSlashing?.bridgeVotingSlashAmount,
    ],
    [
      slashIndicatorConf[network.name]!.doubleSignSlashing?.slashDoubleSignAmount,
      slashIndicatorConf[network.name]!.doubleSignSlashing?.doubleSigningJailUntilBlock,
      slashIndicatorConf[network.name]!.doubleSignSlashing?.doubleSigningOffsetLimitBlock,
    ],
    [
      slashIndicatorConf[network.name]!.unavailabilitySlashing?.unavailabilityTier1Threshold,
      slashIndicatorConf[network.name]!.unavailabilitySlashing?.unavailabilityTier2Threshold,
      slashIndicatorConf[network.name]!.unavailabilitySlashing?.slashAmountForUnavailabilityTier2Threshold,
      slashIndicatorConf[network.name]!.unavailabilitySlashing?.jailDurationForUnavailabilityTier2Threshold,
    ],
    [
      slashIndicatorConf[network.name]!.creditScore?.gainCreditScore,
      slashIndicatorConf[network.name]!.creditScore?.maxCreditScore,
      slashIndicatorConf[network.name]!.creditScore?.bailOutCostMultiplier,
      slashIndicatorConf[network.name]!.creditScore?.cutOffPercentageAfterBailout,
    ],
  ]);

  const nonce = generalRoninConf[network.name].slashIndicatorContract?.nonce;
  // console.log(`Deploying SlashIndicatorProxy (nonce: ${nonce})...`);

  const deployment = await deploy('SlashIndicatorProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, generalRoninConf[network.name]!.governanceAdmin?.address, data],
    nonce,
  });
  verifyAddress(deployment.address, generalRoninConf[network.name].slashIndicatorContract?.address);
};

deploy.tags = ['SlashIndicatorProxy'];
deploy.dependencies = ['SlashIndicatorLogic', '_HelperDposCalculate', 'StakingVestingProxy'];

export default deploy;
