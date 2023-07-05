/// npx hardhat deploy --tags 230406UpdateSlashConditions --network ronin-mainnet

import { BigNumber } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { VoteType } from '../script/proposal';
import { RoninValidatorSet__factory, SlashIndicator__factory } from '../types';
import { SlashIndicatorArguments } from '../utils';
import { explorerUrl, proxyCall, proxyInterface } from './upgradeUtils';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const slashIndicatorProxy = await deployments.get('SlashIndicatorProxy');
  const validatorSetProxy = await deployments.get('RoninValidatorSetProxy');

  const newSlashIndicatorLogic = '0x056500E6028048dB7FCA81Ac307008A9042605f3';
  const newValidatorSetLogic = '0x112119F52eC8760Dacc84907953F2baC6FE5107B';

  const slashInterface = new SlashIndicator__factory().interface;
  const validatorSetInterface = new RoninValidatorSet__factory().interface;
  const newSlashConfig: SlashIndicatorArguments = {
    bridgeOperatorSlashing: {
      missingVotesRatioTier1: 10_00, // 10% (no change)
      missingVotesRatioTier2: 30_00, // 30% (no change)
      jailDurationForMissingVotesRatioTier2: 0, // No jail
      skipBridgeOperatorSlashingThreshold: 50, // (no change)
    },
    bridgeVotingSlashing: {
      bridgeVotingThreshold: 28800 * 3, // ~3 days (no change)
      bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(1_000), // 1.000 RON
    },
    unavailabilitySlashing: {
      unavailabilityTier1Threshold: 100,
      unavailabilityTier2Threshold: 500,
      slashAmountForUnavailabilityTier2Threshold: BigNumber.from(10).pow(18).mul(1_000), // 1.000 RON
      jailDurationForUnavailabilityTier2Threshold: 2 * 28800, // jails for 2 days (no change)
    },
  };

  const slashIndicatorInstructions = [
    proxyCall(
      slashInterface.encodeFunctionData('setBridgeOperatorSlashingConfigs', [
        newSlashConfig.bridgeOperatorSlashing!.missingVotesRatioTier1,
        newSlashConfig.bridgeOperatorSlashing!.missingVotesRatioTier2,
        newSlashConfig.bridgeOperatorSlashing!.jailDurationForMissingVotesRatioTier2,
        newSlashConfig.bridgeOperatorSlashing!.skipBridgeOperatorSlashingThreshold,
      ])
    ),
    proxyCall(
      slashInterface.encodeFunctionData('setUnavailabilitySlashingConfigs', [
        newSlashConfig.unavailabilitySlashing!.unavailabilityTier1Threshold,
        newSlashConfig.unavailabilitySlashing!.unavailabilityTier2Threshold,
        newSlashConfig.unavailabilitySlashing!.slashAmountForUnavailabilityTier2Threshold,
        newSlashConfig.unavailabilitySlashing!.jailDurationForUnavailabilityTier2Threshold,
      ])
    ),
    proxyCall(
      slashInterface.encodeFunctionData('setBridgeVotingSlashingConfigs', [
        newSlashConfig.bridgeVotingSlashing!.bridgeVotingThreshold,
        newSlashConfig.bridgeVotingSlashing!.bridgeVotingSlashAmount,
      ])
    ),
    proxyInterface.encodeFunctionData('upgradeTo', [newSlashIndicatorLogic]),
  ];

  const validatorSetInstructions = [
    proxyCall(validatorSetInterface.encodeFunctionData('setMaxValidatorCandidate', [100])),
    proxyInterface.encodeFunctionData('upgradeTo', [newValidatorSetLogic]),
  ];

  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [
      ...slashIndicatorInstructions.map(() => slashIndicatorProxy.address),
      ...validatorSetInstructions.map(() => validatorSetProxy.address),
    ], // targets
    [...slashIndicatorInstructions, ...validatorSetInstructions].map(() => 0), // values
    [...slashIndicatorInstructions, ...validatorSetInstructions], // datas
    [...slashIndicatorInstructions, ...validatorSetInstructions].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230406UpdateSlashConditions'];

export default deploy;
