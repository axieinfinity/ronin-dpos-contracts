import { expect } from 'chai';
import { network, ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  ScheduledMaintenance__factory,
  ScheduledMaintenance,
  StakingVesting__factory,
  StakingVesting,
} from '../../src/types';
import {
  Network,
  slashIndicatorConf,
  roninValidatorSetConf,
  stakingConfig,
  stakingVestingConfig,
  initAddress,
  scheduledMaintenanceConfig,
} from '../../src/config';
import { BigNumber } from 'ethers';

let stakingVestingContract: StakingVesting;
let scheduledMaintenanceContract: ScheduledMaintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;

const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 0;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

const minValidatorBalance = BigNumber.from(100);
const maxValidatorCandidate = 10;

const bonusPerBlock = BigNumber.from(1);
const topUpAmount = BigNumber.from(10000);
const minMaintenanceBlockPeriod = 100;
const maxMaintenanceBlockPeriod = 1000;
const minOffset = 200;
const maxSchedules = 50;

describe('[Integration] Configuration check', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();

    if (network.name == Network.Hardhat) {
      initAddress[network.name] = {
        governanceAdmin: governanceAdmin.address,
      };
      scheduledMaintenanceConfig[network.name] = {
        minMaintenanceBlockPeriod,
        maxMaintenanceBlockPeriod,
        minOffset,
        maxSchedules,
      };
      slashIndicatorConf[network.name] = {
        misdemeanorThreshold: misdemeanorThreshold,
        felonyThreshold: felonyThreshold,
        slashFelonyAmount: slashFelonyAmount,
        slashDoubleSignAmount: slashDoubleSignAmount,
        felonyJailBlocks: felonyJailDuration,
      };
      roninValidatorSetConf[network.name] = {
        maxValidatorNumber: maxValidatorNumber,
        maxValidatorCandidate: maxValidatorNumber,
        maxPrioritizedValidatorNumber: maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch: numberOfBlocksInEpoch,
        numberOfEpochsInPeriod: numberOfEpochsInPeriod,
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
      };
      stakingVestingConfig[network.name] = {
        bonusPerBlock: bonusPerBlock,
        topupAmount: topUpAmount,
      };
    }

    await deployments.fixture([
      'CalculateAddresses',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'ScheduledMaintenanceProxy',
      'StakingVestingProxy',
    ]);
    const stakingVestingDeployment = await deployments.get('StakingVestingProxy');
    const scheduledMaintenanceDeployment = await deployments.get('ScheduledMaintenanceProxy');
    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    const stakingContractDeployment = await deployments.get('StakingProxy');
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');

    stakingVestingContract = StakingVesting__factory.connect(stakingVestingDeployment.address, deployer);
    scheduledMaintenanceContract = ScheduledMaintenance__factory.connect(
      scheduledMaintenanceDeployment.address,
      deployer
    );
    slashContract = SlashIndicator__factory.connect(slashContractDeployment.address, deployer);
    stakingContract = Staking__factory.connect(stakingContractDeployment.address, deployer);
    validatorContract = RoninValidatorSet__factory.connect(validatorContractDeployment.address, deployer);
  });

  describe('ScheduledMaintenance configuration', () => {
    it('Should the ScheduledMaintenanceContract config the validator contract correctly', async () => {
      expect(await scheduledMaintenanceContract.validatorContract()).eq(validatorContract.address);
    });

    it('Should the ScheduledMaintenanceContract set the maintenance config correctly', async () => {
      expect(await scheduledMaintenanceContract.minMaintenanceBlockPeriod()).eq(minMaintenanceBlockPeriod);
      expect(await scheduledMaintenanceContract.maxMaintenanceBlockPeriod()).eq(maxMaintenanceBlockPeriod);
      expect(await scheduledMaintenanceContract.minOffset()).eq(minOffset);
      expect(await scheduledMaintenanceContract.maxSchedules()).eq(maxSchedules);
    });
  });

  describe('StakingVesting configuration', () => {
    it('Should the StakingVestingContract config the validator contract correctly', async () => {
      expect(await stakingVestingContract.validatorContract()).eq(validatorContract.address);
    });

    it('Should the StakingVestingContract config the block bonus correctly', async () => {
      expect(await stakingVestingContract.blockBonus(0)).eq(bonusPerBlock);
      expect(await stakingVestingContract.blockBonus(Math.floor(Math.random() * 1_000_000))).eq(bonusPerBlock);
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
      expect(_maxValidatorCandidate).to.eq(maxValidatorNumber);
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
      expect(_felonyJailDuration).to.eq(felonyJailDuration);
    });
  });
});
