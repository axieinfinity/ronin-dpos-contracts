import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';

import { TrustedOrganizationStruct } from './types/IRoninTrustedOrganization';

export const DEFAULT_ADDRESS = '0x0000000000000000000000000000000000000000';
export const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
export const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';

export enum Network {
  Local = 'local',
  Hardhat = 'hardhat',
  Devnet = 'ronin-devnet',
  Testnet = 'ronin-testnet',
  Mainnet = 'ronin-mainnet',
  Goerli = 'goerli',
  Ethereum = 'ethereum',
}

export type LiteralNetwork = Network | string;

export const randomAddress = () => {
  return new ethers.Wallet(ethers.utils.randomBytes(32)).address;
};

export const randomBigNumber = () => {
  const hexString = Array.from(Array(64))
    .map(() => Math.round(Math.random() * 0xf).toString(16))
    .join('');
  return BigNumber.from(`0x${hexString}`);
};

export interface AddressExtended {
  address: Address;
  nonce?: number;
}

export interface GeneralConfig {
  [network: LiteralNetwork]: {
    governanceAdmin?: AddressExtended;
    maintenanceContract?: AddressExtended;
    stakingVestingContract?: AddressExtended;
    slashIndicatorContract?: AddressExtended;
    stakingContract?: AddressExtended;
    validatorContract?: AddressExtended;
    roninTrustedOrganizationContract?: AddressExtended;
    bridgeTrackingContract?: AddressExtended;
    startedAtBlock: BigNumberish;
    bridgeContract: Address;
  };
}

export interface MaintenanceArguments {
  minMaintenanceDurationInBlock?: BigNumberish;
  maxMaintenanceDurationInBlock?: BigNumberish;
  minOffsetToStartSchedule?: BigNumberish;
  maxOffsetToStartSchedule?: BigNumberish;
  maxSchedules?: BigNumberish;
}

export interface RoninTrustedOrganizationArguments {
  trustedOrganizations?: TrustedOrganizationStruct[];
  numerator?: BigNumberish;
  denominator?: BigNumberish;
}

export interface RoninTrustedOrganizationConfig {
  [network: LiteralNetwork]: RoninTrustedOrganizationArguments | undefined;
}

export interface MaintenanceConfig {
  [network: LiteralNetwork]: MaintenanceArguments | undefined;
}

export interface StakingArguments {
  minValidatorStakingAmount?: BigNumberish;
  cooldownSecsToUndelegate?: BigNumberish;
  waitingSecsToRevoke?: BigNumberish;
}

export interface StakingConfig {
  [network: LiteralNetwork]: StakingArguments | undefined;
}

export interface StakingVestingArguments {
  blockProducerBonusPerBlock?: BigNumberish;
  bridgeOperatorBonusPerBlock?: BigNumberish;
  topupAmount?: BigNumberish;
}

export interface StakingVestingConfig {
  [network: LiteralNetwork]: StakingVestingArguments | undefined;
}

export interface BridgeOperatorSlashingConfig {
  missingVotesRatioTier1?: BigNumberish;
  missingVotesRatioTier2?: BigNumberish;
  jailDurationForMissingVotesRatioTier2?: BigNumberish;
  skipBridgeOperatorSlashingThreshold?: BigNumberish;
}

export interface BridgeVotingSlashingConfig {
  bridgeVotingThreshold?: BigNumberish;
  bridgeVotingSlashAmount?: BigNumberish;
}

export interface DoubleSignSlashingConfig {
  slashDoubleSignAmount?: BigNumberish;
  doubleSigningJailUntilBlock?: BigNumberish;
}

export interface UnavailabilitySlashing {
  unavailabilityTier1Threshold?: BigNumberish;
  unavailabilityTier2Threshold?: BigNumberish;
  slashAmountForUnavailabilityTier2Threshold?: BigNumberish;
  jailDurationForUnavailabilityTier2Threshold?: BigNumberish;
}

export interface CreditScoreConfig {
  gainCreditScore?: BigNumberish;
  maxCreditScore?: BigNumberish;
  bailOutCostMultiplier?: BigNumberish;
  cutOffPercentageAfterBailout?: BigNumberish;
}

export interface SlashIndicatorArguments {
  bridgeOperatorSlashing?: BridgeOperatorSlashingConfig;
  bridgeVotingSlashing?: BridgeVotingSlashingConfig;
  doubleSignSlashing?: DoubleSignSlashingConfig;
  unavailabilitySlashing?: UnavailabilitySlashing;
  creditScore?: CreditScoreConfig;
}

export interface SlashIndicatorConfig {
  [network: LiteralNetwork]: SlashIndicatorArguments | undefined;
}

export interface RoninValidatorSetArguments {
  maxValidatorNumber?: BigNumberish;
  maxValidatorCandidate?: BigNumberish;
  maxPrioritizedValidatorNumber?: BigNumberish;
  numberOfBlocksInEpoch?: BigNumberish;
  minEffectiveDaysOnwards?: BigNumberish;
}

export interface RoninValidatorSetConfig {
  [network: LiteralNetwork]: RoninValidatorSetArguments | undefined;
}

export interface GovernanceAdminArguments {
  proposalExpiryDuration?: BigNumberish;
}

export interface GovernanceAdminConfig {
  [network: LiteralNetwork]: GovernanceAdminArguments | undefined;
}

export interface MainchainGovernanceAdminArguments {
  roleSetter?: Address;
  relayers?: Address[];
}

export interface MainchainGovernanceAdminConfig {
  [network: LiteralNetwork]: MainchainGovernanceAdminArguments | undefined;
}
