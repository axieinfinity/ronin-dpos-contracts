import { BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';

import { TrustedOrganizationStruct } from './types/IRoninTrustedOrganization';

export const DEFAULT_ADDRESS = '0x0000000000000000000000000000000000000000';
export const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
export const MODERATOR_ROLE = '0x71f3d55856e4058ed06ee057d79ada615f65cdf5f9ee88181b914225088f834f';
export const TARGET_ROLE = '0x7eae605229c67d878c4d7fbf24379ada222941e36ec4e2a7c261d740a528b16f';
export const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
export const MAX_UINT256 = BigNumber.from(
  '115792089237316195423570985008687907853269984665640564039457584007913129639936'
);
export const MAX_UINT255 = BigNumber.from(
  '57896044618658097711785492504343953926634992332820282019728792003956564819968'
);

export const FORWARDER_ADMIN_SLOT = '0xa8c82e6b38a127695961bbff56774712a221ab251224d4167eab01e23fcee6ca';
export const FORWARDER_TARGET_SLOT = '0x58221d865d4bfcbfe437720ee0c958ac3269c4e9c775f643bf474ed980d61168';
export const FORWARDER_MODERATOR_SLOT = '0xcbec2a70e8f0a52aeb8f96e02517dc497e58d9a6fa86ab4056563f1e6baf3d3e';

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
    roninChainId?: BigNumberish;
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
  cooldownSecsToMaintain?: BigNumberish;
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
  doubleSigningOffsetLimitBlock?: BigNumberish;
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
  emergencyExitLockedAmount?: BigNumberish;
  emergencyExpiryDuration?: BigNumberish;
}

export interface RoninValidatorSetConfig {
  [network: LiteralNetwork]: RoninValidatorSetArguments | undefined;
}

export interface RoninGovernanceAdminArguments {
  proposalExpiryDuration?: BigNumberish;
}

export interface RoninGovernanceAdminConfig {
  [network: LiteralNetwork]: RoninGovernanceAdminArguments | undefined;
}

export interface MainchainGovernanceAdminArguments {
  roleSetter?: Address;
  relayers?: Address[];
}

export interface MainchainGovernanceAdminConfig {
  [network: LiteralNetwork]: MainchainGovernanceAdminArguments | undefined;
}

export interface VaultForwarderArguments {
  vaultId: string;
  targets?: Address[];
  admin?: Address;
  moderator?: Address;
}

export interface VaultForwarderConfig {
  [network: LiteralNetwork]: VaultForwarderArguments[] | undefined;
}
