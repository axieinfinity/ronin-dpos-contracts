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
} from '../../../src/types';
import { StakingVestingArguments } from '../../../src/utils';
import { generalRoninConf } from '../../../src/configs/config';
import { defaultTestConfig } from './fixture';

let maintenanceContract: Maintenance;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;
let slashContract: SlashIndicator;
let stakingVestingContract: StakingVesting;

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

export const initializeTestSuite = async (input: InitializeTestSuiteInput) => {
  if (input.maintenanceContractAddress) {
    maintenanceContract = Maintenance__factory.connect(input.maintenanceContractAddress!, input.deployer);
  }

  if (input.stakingContractAddress) {
    stakingContract = Staking__factory.connect(input.stakingContractAddress!, input.deployer);
  }

  if (input.validatorContractAddress) {
    validatorContract = RoninValidatorSet__factory.connect(input.validatorContractAddress!, input.deployer);
  }

  if (input.slashContractAddress) {
    slashContract = SlashIndicator__factory.connect(input.slashContractAddress!, input.deployer);
  }

  if (input.stakingVestingAddress) {
    stakingVestingContract = StakingVesting__factory.connect(input.stakingVestingAddress!, input.deployer);
  }

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
