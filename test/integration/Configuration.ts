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
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Network, slashIndicatorConf, roninValidatorSetConf, stakingConfig, initAddress } from '../../src/config';
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
const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;

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
        maxValidatorNumber: 21,
        numberOfBlocksInEpoch: 600,
        numberOfEpochsInPeriod: 48, // 1 day
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
        maxValidatorCandidate: maxValidatorNumber,
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
    it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
      let _stakingContract = await validatorContract.stakingContract();
      expect(_stakingContract).to.eq(stakingContract.address);
    });

    it('Should the ValidatorSetContract config the Slashing correctly', async () => {
      let _slashingContract = await validatorContract.slashIndicatorContract();
      expect(_slashingContract).to.eq(slashContract.address);
    });
  });

  describe('StakingContract configuration', async () => {
    it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
      let _validatorSetContract = await stakingContract.validatorContract();
      expect(_validatorSetContract).to.eq(validatorContract.address);
    });
  });

  describe('SlashIndicatorContract configuration', async () => {
    it('Should the SlashIndicatorContract config the ValidatorSetContract correctly', async () => {
      let _validatorSetContract = await slashContract.validatorContract();
      expect(_validatorSetContract).to.eq(validatorContract.address);
    });
  });
});
