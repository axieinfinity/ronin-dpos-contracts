import { BigNumber } from 'ethers';
import { deployments, ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import {
  MainchainGovernanceAdminArguments,
  mainchainGovernanceAdminConf,
  MaintenanceArguments,
  maintenanceConf,
  Network,
  RoninGovernanceAdminArguments,
  roninGovernanceAdminConf,
  RoninTrustedOrganizationArguments,
  roninTrustedOrganizationConf,
  RoninValidatorSetArguments,
  roninValidatorSetConf,
  SlashIndicatorArguments,
  slashIndicatorConf,
  StakingArguments,
  stakingConfig,
  StakingVestingArguments,
  stakingVestingConfig,
} from '../../src/config';

export interface InitTestOutput {
  roninGovernanceAdminAddress: Address;
  mainchainGovernanceAdminAddress: Address;
  maintenanceContractAddress: Address;
  roninTrustedOrganizationAddress: Address;
  mainchainRoninTrustedOrganizationAddress: Address;
  slashContractAddress: Address;
  stakingContractAddress: Address;
  stakingVestingContractAddress: Address;
  validatorContractAddress: Address;
}

export const defaultTestConfig = {
  felonyJailBlocks: 28800 * 2,
  misdemeanorThreshold: 5,
  felonyThreshold: 10,
  slashFelonyAmount: BigNumber.from(10).pow(18).mul(1),
  slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10),
  doubleSigningConstrainBlocks: 28800,
  bridgeVotingThreshold: 28800 * 3,
  bridgeVotingSlashAmount: BigNumber.from(10).pow(18).mul(10_000),

  maxValidatorNumber: 4,
  maxPrioritizedValidatorNumber: 0,
  numberOfBlocksInEpoch: 600,
  numberOfEpochsInPeriod: 48,

  minValidatorBalance: BigNumber.from(100),
  maxValidatorCandidate: 10,

  validatorBonusPerBlock: BigNumber.from(1),
  bridgeOperatorBonusPerBlock: BigNumber.from(1),
  topupAmount: BigNumber.from(100000000000),
  minMaintenanceBlockPeriod: 100,
  maxMaintenanceBlockPeriod: 1000,
  minOffset: 200,
  maxSchedules: 2,

  trustedOrganizations: [],
  numerator: 0,
  denominator: 1,

  roleSetter: ethers.constants.AddressZero,
  bridgeContract: ethers.constants.AddressZero,
  relayers: [],
};

export const initTest = (id: string) =>
  deployments.createFixture<
    InitTestOutput,
    MaintenanceArguments &
      StakingArguments &
      StakingVestingArguments &
      SlashIndicatorArguments &
      RoninValidatorSetArguments &
      RoninTrustedOrganizationArguments &
      RoninGovernanceAdminArguments &
      MainchainGovernanceAdminArguments
  >(async ({ deployments }, options) => {
    if (network.name == Network.Hardhat) {
      maintenanceConf[network.name] = {
        minMaintenanceBlockPeriod: options?.minMaintenanceBlockPeriod ?? defaultTestConfig.minMaintenanceBlockPeriod,
        maxMaintenanceBlockPeriod: options?.maxMaintenanceBlockPeriod ?? defaultTestConfig.maxMaintenanceBlockPeriod,
        minOffset: options?.minOffset ?? defaultTestConfig.minOffset,
        maxSchedules: options?.maxSchedules ?? defaultTestConfig.maxSchedules,
      };
      slashIndicatorConf[network.name] = {
        bridgeVotingThreshold: options?.bridgeVotingThreshold ?? defaultTestConfig.bridgeVotingThreshold,
        bridgeVotingSlashAmount: options?.bridgeVotingSlashAmount ?? defaultTestConfig.bridgeVotingSlashAmount,
        misdemeanorThreshold: options?.misdemeanorThreshold ?? defaultTestConfig.misdemeanorThreshold,
        felonyThreshold: options?.felonyThreshold ?? defaultTestConfig.felonyThreshold,
        slashFelonyAmount: options?.slashFelonyAmount ?? defaultTestConfig.slashFelonyAmount,
        slashDoubleSignAmount: options?.slashDoubleSignAmount ?? defaultTestConfig.slashDoubleSignAmount,
        felonyJailBlocks: options?.felonyJailBlocks ?? defaultTestConfig.felonyJailBlocks,
        doubleSigningConstrainBlocks:
          options?.doubleSigningConstrainBlocks ?? defaultTestConfig.doubleSigningConstrainBlocks,
      };
      roninValidatorSetConf[network.name] = {
        maxValidatorNumber: options?.maxValidatorNumber ?? defaultTestConfig.maxValidatorNumber,
        maxValidatorCandidate: options?.maxValidatorCandidate ?? defaultTestConfig.maxValidatorCandidate,
        maxPrioritizedValidatorNumber:
          options?.maxPrioritizedValidatorNumber ?? defaultTestConfig.maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch: options?.numberOfBlocksInEpoch ?? defaultTestConfig.numberOfBlocksInEpoch,
        numberOfEpochsInPeriod: options?.numberOfEpochsInPeriod ?? defaultTestConfig.numberOfEpochsInPeriod,
      };
      stakingConfig[network.name] = {
        minValidatorBalance: options?.minValidatorBalance ?? defaultTestConfig.minValidatorBalance,
      };
      stakingVestingConfig[network.name] = {
        validatorBonusPerBlock: options?.validatorBonusPerBlock ?? defaultTestConfig.validatorBonusPerBlock,
        bridgeOperatorBonusPerBlock:
          options?.bridgeOperatorBonusPerBlock ?? defaultTestConfig.bridgeOperatorBonusPerBlock,
        topupAmount: options?.topupAmount ?? defaultTestConfig.topupAmount,
      };
      roninTrustedOrganizationConf[network.name] = {
        trustedOrganizations: options?.trustedOrganizations ?? defaultTestConfig.trustedOrganizations,
        numerator: options?.numerator ?? defaultTestConfig.numerator,
        denominator: options?.denominator ?? defaultTestConfig.denominator,
      };
      roninGovernanceAdminConf[network.name] = {
        bridgeContract: options?.bridgeContract ?? defaultTestConfig.bridgeContract,
      };
      mainchainGovernanceAdminConf[network.name] = {
        roleSetter: options?.roleSetter ?? defaultTestConfig.roleSetter,
        bridgeContract: options?.bridgeContract ?? defaultTestConfig.bridgeContract,
        relayers: options?.relayers ?? defaultTestConfig.relayers,
      };
    }

    await deployments.fixture([
      'CalculateAddresses',
      'RoninGovernanceAdmin',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'MaintenanceProxy',
      'StakingVestingProxy',
      'MainchainGovernanceAdmin',
      'MainchainRoninTrustedOrganizationProxy',
      id,
    ]);

    const roninGovernanceAdminDeployment = await deployments.get('RoninGovernanceAdmin');
    const mainchainGovernanceAdminDeployment = await deployments.get('MainchainGovernanceAdmin');
    const maintenanceContractDeployment = await deployments.get('MaintenanceProxy');
    const roninTrustedOrganizationDeployment = await deployments.get('RoninTrustedOrganizationProxy');
    const mainchainRoninTrustedOrganizationDeployment = await deployments.get('MainchainRoninTrustedOrganizationProxy');
    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    const stakingContractDeployment = await deployments.get('StakingProxy');
    const stakingVestingContractDeployment = await deployments.get('StakingVestingProxy');
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');

    return {
      roninGovernanceAdminAddress: roninGovernanceAdminDeployment.address,
      mainchainGovernanceAdminAddress: mainchainGovernanceAdminDeployment.address,
      maintenanceContractAddress: maintenanceContractDeployment.address,
      roninTrustedOrganizationAddress: roninTrustedOrganizationDeployment.address,
      mainchainRoninTrustedOrganizationAddress: mainchainRoninTrustedOrganizationDeployment.address,
      slashContractAddress: slashContractDeployment.address,
      stakingContractAddress: stakingContractDeployment.address,
      stakingVestingContractAddress: stakingVestingContractDeployment.address,
      validatorContractAddress: validatorContractDeployment.address,
    };
  }, id);
