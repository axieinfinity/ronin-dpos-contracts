import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';
import {
  Maintenance,
  Maintenance__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  StakingVesting,
  StakingVesting__factory,
  Staking__factory,
  Profile,
  Profile__factory,
  RoninTrustedOrganization,
  RoninTrustedOrganization__factory,
} from '../../../src/types';
import { StakingVestingArguments } from '../../../src/utils';
import { defaultTestConfig } from './fixture';

let maintenanceContract: Maintenance | undefined;
let stakingContract: Staking | undefined;
let validatorContract: RoninValidatorSet | undefined;
let slashContract: SlashIndicator | undefined;
let stakingVestingContract: StakingVesting | undefined;
let profileContract: Profile | undefined;
let roninTrustedOrgContract: RoninTrustedOrganization | undefined;

export interface InitializeTestSuiteInput {
  deployer: SignerWithAddress;
  fastFinalityTrackingAddress: Address;
  stakingVestingArgs?: StakingVestingArguments;
  profileAddress: Address;
  maintenanceContractAddress?: Address;
  slashContractAddress?: Address;
  stakingContractAddress?: Address;
  validatorContractAddress?: Address;
  stakingVestingAddress?: Address;
  roninTrustedOrganizationAddress?: Address;
}

interface InitREP2Input {
  fastFinalityTrackingAddress: Address;
  profileAddress: Address;
  validatorContract?: RoninValidatorSet;
  slashContract?: SlashIndicator;
  stakingVestingContract?: StakingVesting;
  stakingVestingArgs?: StakingVestingArguments;
}

interface InitREP3Input {
  profileAddress: Address;
  maintenanceContract?: Maintenance;
  stakingContract?: Staking;
  validatorContract?: RoninValidatorSet;
}

interface InitREP4Input {
  profileContract?: Profile;
  stakingContract?: Staking;
  roninTrustedOrgContract?: RoninTrustedOrganization;
}

export const initializeTestSuite = async (input: InitializeTestSuiteInput) => {
  // Cheat the instance of `input`, since it propagates among tests, and does not get cleared.
  maintenanceContract = input.maintenanceContractAddress
    ? Maintenance__factory.connect(input.maintenanceContractAddress!, input.deployer)
    : undefined;

  stakingContract = input.stakingContractAddress
    ? Staking__factory.connect(input.stakingContractAddress!, input.deployer)
    : undefined;

  validatorContract = input.validatorContractAddress
    ? RoninValidatorSet__factory.connect(input.validatorContractAddress!, input.deployer)
    : undefined;

  slashContract = input.slashContractAddress
    ? SlashIndicator__factory.connect(input.slashContractAddress!, input.deployer)
    : undefined;

  stakingVestingContract = input.stakingVestingAddress
    ? StakingVesting__factory.connect(input.stakingVestingAddress!, input.deployer)
    : undefined;

  profileContract = input.profileAddress ? Profile__factory.connect(input.profileAddress!, input.deployer) : undefined;

  roninTrustedOrgContract = input.roninTrustedOrganizationAddress
    ? RoninTrustedOrganization__factory.connect(input.roninTrustedOrganizationAddress!, input.deployer)
    : undefined;

  await upgradeRep2({
    fastFinalityTrackingAddress: input.fastFinalityTrackingAddress,
    profileAddress: input.profileAddress,
    validatorContract,
    slashContract,
    stakingVestingArgs: input.stakingVestingArgs,
    stakingVestingContract,
  });

  await upgradeRep3({
    profileAddress: input.profileAddress,
    maintenanceContract,
    stakingContract,
    validatorContract,
  });

  await upgradeRep4({
    profileContract,
    stakingContract,
    roninTrustedOrgContract
  });
};

const upgradeRep2 = async (input: InitREP2Input) => {
  if (input.validatorContract) {
    await input.validatorContract.initializeV3(input.fastFinalityTrackingAddress);
  }

  if (input.stakingVestingContract) {
    await input.stakingVestingContract.initializeV3(
      input.stakingVestingArgs!.fastFinalityRewardPercent ??
        defaultTestConfig.stakingVestingArguments?.fastFinalityRewardPercent!
    );
  }

  if (input.slashContract) {
    await input.slashContract.initializeV3(input.profileAddress);
  }
};

const upgradeRep3 = async (input: InitREP3Input) => {
  if (input.maintenanceContract) {
    await input.maintenanceContract.initializeV3(input.profileAddress);
  }

  if (input.stakingContract) {
    await input.stakingContract.initializeV3(input.profileAddress);
  }

  if (input.validatorContract) {
    await input.validatorContract.initializeV4(input.profileAddress);
  }
};

const upgradeRep4 = async (input: InitREP4Input) => {
  if (input.profileContract) {
    await input.profileContract.initializeV2(input.stakingContract?.address!);
    await input.profileContract.initializeV3(input.roninTrustedOrgContract?.address!);
  }

  if (input.roninTrustedOrgContract) {
    await input.roninTrustedOrgContract.initializeV2(input.profileContract?.address!);
  }
};
