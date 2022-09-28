import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, ContractTransaction } from 'ethers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetExtended__factory,
  MockRoninValidatorSetExtended,
} from '../../src/types';
import { expects as StakingExpects } from '../helpers/reward-calculation';
import { expects as ValidatorSetExpects } from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';
import { GovernanceAdminInterface, initTest } from '../helpers/fixture';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtended;
let governanceAdmin: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyThreshold = 10;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;
const minValidatorBalance = BigNumber.from(100);
const maxValidatorNumber = 3;

describe('[Integration] Wrap up epoch', () => {
  const blockRewardAmount = BigNumber.from(2);

  before(async () => {
    [deployer, coinbase, governor, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    governanceAdmin = new GovernanceAdminInterface(governor);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress } = await initTest(
      'ActionWrapUpEpoch'
    )({
      felonyThreshold,
      slashFelonyAmount,
      slashDoubleSignAmount,
      minValidatorBalance,
      maxValidatorNumber,
      governanceAdmin: governanceAdmin.address,
    });
    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    governanceAdmin.upgrade(validatorContract.address, mockValidatorLogic.address);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
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
          .proposeValidator(
            validatorCandidates[i].address,
            validatorCandidates[i].address,
            validatorCandidates[i].address,
            2_00,
            {
              value: minValidatorBalance.mul(2).add(i),
            }
          );
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

      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      validatorContract = validatorContract.connect(coinbase);
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
          await validatorContract.endPeriod();
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
      before(async () => {
        await validatorContract.addValidators(validators.map((v) => v.address));
        await Promise.all(validators.map((v) => slashContract.connect(coinbase).slash(v.address)));
      });

      it('Should the ValidatorSet not reset counter, when the period is not ended', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expect(
          await Promise.all(validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.address)))
        ).eql(validators.map((v) => (v.address == coinbase.address ? BigNumber.from(0) : BigNumber.from(1))));
      });

      it('Should the ValidatorSet reset counter in SlashIndicator contract', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expect(
          await Promise.all(validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.address)))
        ).eql(validators.map(() => BigNumber.from(0)));
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
          .proposeValidator(validators[i].address, validators[i].address, validators[i].address, 2_00, {
            value: minValidatorBalance.mul(3).add(i),
          });
      }

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      coinbase = validators[3];
      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
      validatorContract = validatorContract.connect(coinbase);
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
          await slashContract.connect(coinbase).slash(validators[1].address);
        }
      });

      it('Should the validator set get updated (excluding the slashed validator)', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });

        await ValidatorSetExpects.emitValidatorSetUpdatedEvent(
          wrapUpTx,
          [validators[0], validators[2], coinbase].map((_) => _.address).reverse()
        );
      });

      it('Should the validators in the previous epoch (including slashed one) got slashing counter reset, when the epoch ends', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        expect(
          await Promise.all(validators.map(async (v) => slashContract.currentUnavailabilityIndicator(v.address)))
        ).eql(validators.map(() => BigNumber.from(0)));
      });
    });
  });
});
