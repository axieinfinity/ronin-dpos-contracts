import { expect } from 'chai';
import { network, ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetEpochSetter__factory,
  MockRoninValidatorSetEpochSetter,
  ProxyAdmin__factory,
} from '../../src/types';
import {
  Network,
  slashIndicatorConf,
  roninValidatorSetConf,
  stakingConfig,
  initAddress,
  stakingVestingConfig,
} from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { mineBatchTxs } from '../utils';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetEpochSetter;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;

const maxValidatorNumber = 3;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

const minValidatorBalance = BigNumber.from(100);
const maxValidatorCandidate = 10;

const bonusPerBlock = BigNumber.from(1);
const topUpAmount = BigNumber.from(10000);

describe('[Integration] Submit Block Reward', () => {
  const blockRewardAmount = BigNumber.from(2);

  before(async () => {
    [deployer, coinbase, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

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
        maxValidatorCandidate: maxValidatorCandidate,
      };
      stakingVestingConfig[network.name] = {
        bonusPerBlock: bonusPerBlock,
        topupAmount: topUpAmount,
      };
    }

    await deployments.fixture([
      'ProxyAdmin',
      'CalculateAddresses',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'StakingVestingProxy',
    ]);

    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    slashContract = SlashIndicator__factory.connect(slashContractDeployment.address, deployer);

    const stakingContractDeployment = await deployments.get('StakingProxy');
    stakingContract = Staking__factory.connect(stakingContractDeployment.address, deployer);

    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContract = MockRoninValidatorSetEpochSetter__factory.connect(
      validatorContractDeployment.address,
      deployer
    );

    const mockValidatorLogic = await new MockRoninValidatorSetEpochSetter__factory(deployer).deploy();
    await mockValidatorLogic.deployed();

    const proxyAdminDeployment = await deployments.get('ProxyAdmin');
    let proxyAdminContract = ProxyAdmin__factory.connect(proxyAdminDeployment.address, deployer);

    await proxyAdminContract.upgrade(validatorContract.address, mockValidatorLogic.address);
  });

  describe('Configuration check', async () => {
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
  });

  describe('One validator submits block reward', async () => {
    let validator: SignerWithAddress;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorBalance.mul(2);
      validator = validatorCandidates[0];
      await stakingContract.connect(validator).proposeValidator(validator.address, validator.address, 2_00, {
        value: initStakingAmount,
      });
      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });
    });

    after(async () => {
      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    });

    it('Should validator can submit block reward', async () => {
      await network.provider.send('hardhat_setCoinbase', [validator.address]);
      validatorContract = validatorContract.connect(validator);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of submitting reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'BlockRewardSubmitted')
        .withArgs(validator.address, blockRewardAmount);
    });

    it.skip('Should the ValidatorSetContract update mining reward', async () => {});

    it('Should the StakingContract emit event of recording reward', async () => {
      await expect(submitRewardTx).to.emit(stakingContract, 'PendingPoolUpdated').withArgs(validator.address, anyValue);
    });

    it.skip('Should the StakingContract record update for new block reward', async () => {});
  });

  describe('In-jail validator submits block reward', async () => {
    let validator: SignerWithAddress;
    let submitRewardTx: ContractTransaction;

    before(async () => {
      let initStakingAmount = minValidatorBalance.mul(2);
      validator = validatorCandidates[1];
      await stakingContract.connect(validator).proposeValidator(validator.address, validator.address, 2_00, {
        value: initStakingAmount,
      });

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      for (let i = 0; i < felonyThreshold; i++) {
        await slashContract.connect(coinbase).slash(validator.address);
      }
    });

    it('Should in-jail validator submit block reward', async () => {
      await network.provider.send('hardhat_setCoinbase', [validator.address]);
      validatorContract = validatorContract.connect(validator);

      submitRewardTx = await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    it('Should the ValidatorSetContract emit event of deprecating reward', async () => {
      await expect(submitRewardTx)
        .to.emit(validatorContract, 'RewardDeprecated')
        .withArgs(validator.address, blockRewardAmount);
    });

    it('Should the StakingContract not emit event of recording reward', async () => {
      expect(submitRewardTx).not.to.emit(stakingContract, 'PendingPoolUpdated');
    });
  });
});
