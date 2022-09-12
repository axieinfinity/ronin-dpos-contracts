import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Network, slashIndicatorConf, roninValidatorSetConf, stakingConfig, initAddress } from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { mineBatchTxs } from '../utils';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetEpochSetterAndQueryInfo;

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
const blockRewardAmount = BigNumber.from(2);

describe('[Integration] Submit Block Reward', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 5);
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
        maxValidatorNumber: 21,
        numberOfBlocksInEpoch: 600,
        numberOfEpochsInPeriod: 48, // 1 day
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
        maxValidatorCandidate: maxValidatorNumber,
      };
    }

    const nonce = await deployer.getTransactionCount();
    const roninValidatorSetAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 4 });

    const slashLogicContract = await new SlashIndicator__factory(deployer).deploy();
    await slashLogicContract.deployed();

    const slashProxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      slashLogicContract.address,
      proxyAdmin.address,
      slashLogicContract.interface.encodeFunctionData('initialize', [
        slashIndicatorConf[network.name]!.misdemeanorThreshold,
        slashIndicatorConf[network.name]!.felonyThreshold,
        roninValidatorSetAddr,
        slashIndicatorConf[network.name]!.slashFelonyAmount,
        slashIndicatorConf[network.name]!.slashDoubleSignAmount,
        slashIndicatorConf[network.name]!.felonyJailBlocks,
      ])
    );
    await slashProxyContract.deployed();
    slashContract = SlashIndicator__factory.connect(slashProxyContract.address, deployer);

    validatorContract = await new MockRoninValidatorSetEpochSetterAndQueryInfo__factory(deployer).deploy(
      governanceAdmin.address,
      slashContract.address,
      stakingContractAddr,
      maxValidatorNumber
    );
    await validatorContract.deployed();

    const stakingLogicContract = await new Staking__factory(deployer).deploy();
    await stakingLogicContract.deployed();

    const stakingProxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      stakingLogicContract.address,
      proxyAdmin.address,
      stakingLogicContract.interface.encodeFunctionData('initialize', [
        validatorContract.address,
        governanceAdmin.address,
        100,
        minValidatorBalance,
      ])
    );
    await stakingProxyContract.deployed();
    stakingContract = Staking__factory.connect(stakingProxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase()).eq(validatorContract.address.toLowerCase());
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
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
