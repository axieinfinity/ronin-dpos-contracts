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
} from '../../src/types';
import {
  Network,
  slashIndicatorConf,
  roninValidatorSetConf,
  stakingConfig,
  stakingVestingConfig,
  initAddress,
} from '../../src/config';
import { BigNumber } from 'ethers';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;
const maxValidatorNumber = 4;
const minValidatorBalance = BigNumber.from(100);
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;
const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const bonusPerBlock = BigNumber.from(1);
const topUpAmount = BigNumber.from(10000);

describe('[Integration] Configuration check', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();

    if (network.name == Network.Hardhat) {
      initAddress[network.name] = {
        governanceAdmin: governanceAdmin.address,
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
        numberOfBlocksInEpoch: numberOfBlocksInEpoch,
        numberOfEpochsInPeriod: numberOfEpochsInPeriod,
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
        maxValidatorCandidate: maxValidatorNumber,
      };
      stakingVestingConfig[network.name] = {
        bonusPerBlock: bonusPerBlock,
        topupAmount: topUpAmount,
      };
    }

    await deployments.fixture(['CalculateAddresses', 'RoninValidatorSetProxy', 'SlashIndicatorProxy', 'StakingProxy']);

    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    slashContract = SlashIndicator__factory.connect(slashContractDeployment.address, deployer);

    const stakingContractDeployment = await deployments.get('StakingProxy');
    stakingContract = Staking__factory.connect(stakingContractDeployment.address, deployer);

    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContract = RoninValidatorSet__factory.connect(validatorContractDeployment.address, deployer);
  });

  describe('ValidatorSetContract configuration', async () => {
    it('Should config the governanceAdmin correctly', async () => {
      let _governanceAdmin = await validatorContract.governanceAdmin();
      expect(_governanceAdmin).to.eq(governanceAdmin.address);
    });

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
    it('Should config the governanceAdmin correctly', async () => {
      let _governanceAdmin = await stakingContract.governanceAdmin();
      expect(_governanceAdmin).to.eq(governanceAdmin.address);
    });

    it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
      let _validatorSetContract = await stakingContract.validatorContract();
      expect(_validatorSetContract).to.eq(validatorContract.address);
    });

    it('Should config the minValidatorBalance correctly', async () => {
      let _minValidatorBalance = await stakingContract.minValidatorBalance();
      expect(_minValidatorBalance).to.eq(minValidatorBalance);
    });

    it('Should config the maxValidatorCandidate correctly', async () => {
      let _maxValidatorCandidate = await stakingContract.maxValidatorCandidate();
      expect(_maxValidatorCandidate).to.eq(maxValidatorNumber);
    });
  });

  describe('SlashIndicatorContract configuration', async () => {
    it('Should config the governanceAdmin correctly', async () => {
      let _governanceAdmin = await slashContract.governanceAdmin();
      expect(_governanceAdmin).to.eq(governanceAdmin.address);
    });

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
