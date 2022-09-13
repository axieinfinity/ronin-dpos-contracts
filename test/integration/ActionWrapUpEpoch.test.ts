import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

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
import { expects as StakingExpects } from '../../src/script/reward-calculation';
import { expects as SlashExpects } from '../../src/script/slash-indicator';
import { expects as ValidatorSetExpects } from '../../src/script/ronin-validator-set';
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
const maxValidatorNumber = 3;
const minValidatorBalance = BigNumber.from(100);
const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const blockRewardAmount = BigNumber.from(2);

describe('[Integration] Wrap up epoch', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
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

    expect(roninValidatorSetAddr.toLowerCase(), 'validator set contract mismatch').eq(
      validatorContract.address.toLowerCase()
    );
    expect(stakingContractAddr.toLowerCase(), 'staking contract mismatch').eq(stakingContract.address.toLowerCase());
  });

  describe('Configuration test', () => {
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

  describe('Flow test on one validator', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: SignerWithAddress[];

    before(async () => {
      validators = validatorCandidates.slice(0, 4);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validatorCandidates[i])
          .proposeValidator(validatorCandidates[i].address, validatorCandidates[i].address, 2_00, {
            value: minValidatorBalance.mul(2).add(i),
          });
      }

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      await network.provider.send('hardhat_setCoinbase', [validators[3].address]);
      validatorContract = validatorContract.connect(validators[3]);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    after(async () => {
      coinbase = validators[3];
    });

    describe('Wrap up epoch: at the end of the epoch', async () => {
      it('Should validator not be able to wrap up the epoch twice, in the same epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
          let duplicatedWrapUpTx = validatorContract.wrapUpEpoch();

          await expect(duplicatedWrapUpTx).to.be.revertedWith('RoninValidatorSet: query for already wrapped up epoch');
        });
      });

      it('Should validator be able to wrap up the epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
      });

      describe.skip('ValidatorSetContract internal actions', async () => {});

      describe('StakingContract internal actions: settle reward pool', async () => {
        it('Should the StakingContract emit event of settling reward', async () => {
          await StakingExpects.emitSettledPoolsUpdatedEvent(
            wrapUpTx,
            validators
              .slice(1, 4)
              .map((_) => _.address)
              .reverse()
          );
        });
      });
    });

    describe('Wrap up epoch: at the end of the period', async () => {
      it('Should the ValidatorSet not reset counter, when the period is not ended', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        await expect(wrapUpTx).not.to.emit(slashContract, 'UnavailabilityIndicatorsReset');
      });

      it('Should the ValidatorSet reset counter in SlashIndicator contract', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        await SlashExpects.emitUnavailabilityIndicatorsResetEvent(
          wrapUpTx,
          validators
            .slice(1, 4)
            .map((_) => _.address)
            .reverse()
        );
      });
    });
  });

  describe('Flow test on many validators', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: SignerWithAddress[];

    before(async () => {
      validators = validatorCandidates.slice(4, 8);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validators[i])
          .proposeValidator(validators[i].address, validators[i].address, 2_00, {
            value: minValidatorBalance.mul(3).add(i),
          });
      }

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      await network.provider.send('hardhat_setCoinbase', [validators[3].address]);
      validatorContract = validatorContract.connect(validators[3]);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    describe('One validator get slashed between period', async () => {
      before(async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
        });

        for (let i = 0; i < felonyThreshold; i++) {
          await slashContract.connect(validators[3]).slash(validators[1].address);
        }
      });

      it('Should the validator set get updated (excluding the slashed validator)', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });

        await ValidatorSetExpects.emitValidatorSetUpdatedEvent(
          wrapUpTx,
          [validators[0], validators[2], validators[3]].map((_) => _.address).reverse()
        );
      });

      it('Should the validators in the previous epoch (including slashed one) got slashing counter reset, when the epoch ends', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        await SlashExpects.emitUnavailabilityIndicatorsResetEvent(
          wrapUpTx,
          [validators[0], validators[2], validators[3]].map((_) => _.address).reverse()
        );
      });
    });
  });
});
