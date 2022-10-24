import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber } from 'ethers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  Maintenance__factory,
  Maintenance,
  StakingVesting__factory,
  StakingVesting,
} from '../../src/types';
import { initTest } from '../helpers/fixture';

let stakingVestingContract: StakingVesting;
let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyJailBlocks = 28800 * 2;
const misdemeanorThreshold = 5;
const felonyThreshold = 10;
const slashFelonyAmount = BigNumber.from(10).pow(18).mul(1);
const slashDoubleSignAmount = BigNumber.from(10).pow(18).mul(10);

const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 0;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

const minValidatorBalance = BigNumber.from(100);
const maxValidatorCandidate = 10;

const validatorBonusPerBlock = BigNumber.from(1);
const topupAmount = BigNumber.from(10000);
const minMaintenanceBlockPeriod = 100;
const maxMaintenanceBlockPeriod = 1000;
const minOffset = 200;
const maxSchedules = 2;

describe('[Integration] Configuration check', () => {
  before(async () => {
    [coinbase, deployer, governor, ...validatorCandidates] = await ethers.getSigners();
    const {
      maintenanceContractAddress,
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      stakingVestingContractAddress,
    } = await initTest('Configuration')({
      felonyJailBlocks,
      misdemeanorThreshold,
      felonyThreshold,
      slashFelonyAmount,
      slashDoubleSignAmount,
      maxValidatorNumber,
      maxPrioritizedValidatorNumber,
      numberOfBlocksInEpoch,
      numberOfEpochsInPeriod,
      minValidatorBalance,
      maxValidatorCandidate,
      validatorBonusPerBlock,
      topupAmount,
      minMaintenanceBlockPeriod,
      maxMaintenanceBlockPeriod,
      minOffset,
      maxSchedules,
      trustedOrganizations: [governor.address].map((addr) => ({ addr, weight: 100 })),
    });

    stakingVestingContract = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    maintenanceContract = Maintenance__factory.connect(maintenanceContractAddress, deployer);
    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = RoninValidatorSet__factory.connect(validatorContractAddress, deployer);
  });

  describe('Maintenance configuration', () => {
    it('Should the MaintenanceContract config the validator contract correctly', async () => {
      expect(await maintenanceContract.validatorContract()).eq(validatorContract.address);
    });

    it('Should the MaintenanceContract set the maintenance config correctly', async () => {
      expect(await maintenanceContract.minMaintenanceBlockPeriod()).eq(minMaintenanceBlockPeriod);
      expect(await maintenanceContract.maxMaintenanceBlockPeriod()).eq(maxMaintenanceBlockPeriod);
      expect(await maintenanceContract.minOffset()).eq(minOffset);
      expect(await maintenanceContract.maxSchedules()).eq(maxSchedules);
    });
  });

  describe('StakingVesting configuration', () => {
    it('Should the StakingVestingContract config the validator contract correctly', async () => {
      expect(await stakingVestingContract.validatorContract()).eq(validatorContract.address);
    });

    it('Should the StakingVestingContract config the block bonus correctly', async () => {
      expect(await stakingVestingContract.validatorBlockBonus(0)).eq(validatorBonusPerBlock);
      expect(await stakingVestingContract.validatorBlockBonus(Math.floor(Math.random() * 1_000_000))).eq(
        validatorBonusPerBlock
      );
    });
  });

  describe('ValidatorSetContract configuration', async () => {
    it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
      let _stakingContract = await validatorContract.stakingContract();
      expect(_stakingContract).to.eq(stakingContract.address);
    });

    it('Should the ValidatorSetContract config the Slashing correctly', async () => {
      let _slashingContract = await validatorContract.slashIndicatorContract();
      expect(_slashingContract).to.eq(slashContract.address);
    });

    it('Should config the maxValidatorNumber correctly', async () => {
      let _maxValidatorNumber = await validatorContract.maxValidatorNumber();
      expect(_maxValidatorNumber).to.eq(maxValidatorNumber);
    });

    it('Should config the maxValidatorCandidate correctly', async () => {
      let _maxValidatorCandidate = await validatorContract.maxValidatorCandidate();
      expect(_maxValidatorCandidate).to.eq(maxValidatorCandidate);
    });

    it('Should config the numberOfBlocksInEpoch correctly', async () => {
      let _numberOfBlocksInEpoch = await validatorContract.numberOfBlocksInEpoch();
      expect(_numberOfBlocksInEpoch).to.eq(numberOfBlocksInEpoch);
    });

    it('Should config the numberOfEpochsInPeriod correctly', async () => {
      let _numberOfEpochsInPeriod = await validatorContract.numberOfEpochsInPeriod();
      expect(_numberOfEpochsInPeriod).to.eq(numberOfEpochsInPeriod);
    });
  });

  describe('StakingContract configuration', async () => {
    it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
      let _validatorSetContract = await stakingContract.validatorContract();
      expect(_validatorSetContract).to.eq(validatorContract.address);
    });

    it('Should config the minValidatorBalance correctly', async () => {
      let _minValidatorBalance = await stakingContract.minValidatorBalance();
      expect(_minValidatorBalance).to.eq(minValidatorBalance);
    });
  });

  describe('SlashIndicatorContract configuration', async () => {
    it('Should the SlashIndicatorContract config the ValidatorSetContract correctly', async () => {
      let _validatorSetContract = await slashContract.validatorContract();
      expect(_validatorSetContract).to.eq(validatorContract.address);
    });

    it('Should config the misdemeanorThreshold correctly', async () => {
      let _misdemeanorThreshold = await slashContract.misdemeanorThreshold();
      expect(_misdemeanorThreshold).to.eq(misdemeanorThreshold);
    });

    it('Should config the felonyThreshold correctly', async () => {
      let _felonyThreshold = await slashContract.felonyThreshold();
      expect(_felonyThreshold).to.eq(felonyThreshold);
    });

    it('Should config the slashFelonyAmount correctly', async () => {
      let _slashFelonyAmount = await slashContract.slashFelonyAmount();
      expect(_slashFelonyAmount).to.eq(slashFelonyAmount);
    });

    it('Should config the slashDoubleSignAmount correctly', async () => {
      let _slashDoubleSignAmount = await slashContract.slashDoubleSignAmount();
      expect(_slashDoubleSignAmount).to.eq(slashDoubleSignAmount);
    });

    it('Should config the felonyJailDuration correctly', async () => {
      let _felonyJailDuration = await slashContract.felonyJailDuration();
      expect(_felonyJailDuration).to.eq(felonyJailBlocks);
    });
  });
});
