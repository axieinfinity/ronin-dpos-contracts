import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, BytesLike } from 'ethers';
import { deployments, ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import {
  initAddress,
  MaintenanceArguments,
  maintenanceConf,
  Network,
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
import { TransparentUpgradeableProxyV2__factory } from '../../src/types';

export interface InitTestOutput {
  maintenanceContractAddress: Address;
  roninTrustedOrganizationAddress: Address;
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

  maxValidatorNumber: 4,
  maxPrioritizedValidatorNumber: 0,
  numberOfBlocksInEpoch: 600,
  numberOfEpochsInPeriod: 48,

  minValidatorBalance: BigNumber.from(100),
  maxValidatorCandidate: 10,

  bonusPerBlock: BigNumber.from(1),
  topupAmount: BigNumber.from(10000),
  minMaintenanceBlockPeriod: 100,
  maxMaintenanceBlockPeriod: 1000,
  minOffset: 200,
  maxSchedules: 2,

  trustedOrganization: [],
};

export const initTest = (id: string) =>
  deployments.createFixture<
    InitTestOutput,
    MaintenanceArguments &
      StakingArguments &
      StakingVestingArguments &
      SlashIndicatorArguments &
      RoninValidatorSetArguments &
      RoninTrustedOrganizationArguments & { governanceAdmin: Address }
  >(async ({ deployments }, options) => {
    if (network.name == Network.Hardhat) {
      initAddress[network.name] = { governanceAdmin: options?.governanceAdmin ?? ethers.constants.AddressZero };
      maintenanceConf[network.name] = {
        minMaintenanceBlockPeriod: options?.minMaintenanceBlockPeriod ?? defaultTestConfig.minMaintenanceBlockPeriod,
        maxMaintenanceBlockPeriod: options?.maxMaintenanceBlockPeriod ?? defaultTestConfig.maxMaintenanceBlockPeriod,
        minOffset: options?.minOffset ?? defaultTestConfig.minOffset,
        maxSchedules: options?.maxSchedules ?? defaultTestConfig.maxSchedules,
      };
      slashIndicatorConf[network.name] = {
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
        bonusPerBlock: options?.bonusPerBlock ?? defaultTestConfig.bonusPerBlock,
        topupAmount: options?.topupAmount ?? defaultTestConfig.topupAmount,
      };
      roninTrustedOrganizationConf[network.name] = {
        trustedOrganization: options?.trustedOrganization ?? defaultTestConfig.trustedOrganization,
      };
    }

    await deployments.fixture([
      'CalculateAddresses',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'MaintenanceProxy',
      'StakingVestingProxy',
      id,
    ]);

    const maintenanceContractDeployment = await deployments.get('MaintenanceProxy');
    const roninTrustedOrganizationDeployment = await deployments.get('RoninTrustedOrganizationProxy');
    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    const stakingContractDeployment = await deployments.get('StakingProxy');
    const stakingVestingContractDeployment = await deployments.get('StakingVestingProxy');
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');

    return {
      maintenanceContractAddress: maintenanceContractDeployment.address,
      roninTrustedOrganizationAddress: roninTrustedOrganizationDeployment.address,
      slashContractAddress: slashContractDeployment.address,
      stakingContractAddress: stakingContractDeployment.address,
      stakingVestingContractAddress: stakingVestingContractDeployment.address,
      validatorContractAddress: validatorContractDeployment.address,
    };
  }, id);

export class GovernanceAdminInterface {
  signer!: SignerWithAddress;
  address = ethers.constants.AddressZero;
  constructor(signer: SignerWithAddress) {
    this.signer = signer;
    this.address = signer.address;
  }

  functionDelegateCall(to: Address, data: BytesLike) {
    return TransparentUpgradeableProxyV2__factory.connect(to, this.signer).functionDelegateCall(data);
  }

  upgrade(from: Address, to: Address) {
    return TransparentUpgradeableProxyV2__factory.connect(from, this.signer).upgradeTo(to);
  }
}
