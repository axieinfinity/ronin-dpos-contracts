import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetExtended__factory,
  MockRoninValidatorSetExtended,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
} from '../../src/types';

import { expects as RoninValidatorSetExpects } from '../helpers/ronin-validator-set';
import { expects as CandidateManagerExpects } from '../helpers/candidate-manager';
import { mineBatchTxs } from '../helpers/utils';
import { SlashType } from '../../src/script/slash-indicator';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyJailBlocks = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;
const minValidatorBalance = BigNumber.from(100);
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

describe('[Integration] Slash validators', () => {
  before(async () => {
    [deployer, coinbase, governor, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress, roninGovernanceAdminAddress } =
      await initTest('ActionSlashValidators')({
        felonyJailBlocks,
        misdemeanorThreshold,
        felonyThreshold,
        slashFelonyAmount,
        slashDoubleSignAmount,
        minValidatorBalance,
        trustedOrganizations: [
          {
            consensusAddr: governor.address,
            governor: governor.address,
            bridgeVoter: governor.address,
            weight: 100,
            addedBlock: 0,
          },
        ],
      });

    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);

    await network.provider.send('hardhat_mine', [
      ethers.utils.hexStripZeros(BigNumber.from(numberOfBlocksInEpoch * numberOfEpochsInPeriod).toHexString()),
    ]);
  });

  describe('Slash one validator', async () => {
    let expectingValidatorSet: Address[] = [];
    let expectingBlockProducerSet: Address[] = [];
    let period: BigNumberish;

    before(async () => {
      const currentBlock = await ethers.provider.getBlockNumber();
      period = await validatorContract.periodOf(currentBlock);
      await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

      await validatorContract.addValidators([1, 2, 3].map((_) => validatorCandidates[_].address));
    });

    describe('Slash misdemeanor validator', async () => {
      it('Should the ValidatorSet contract emit event', async () => {
        let slasheeIdx = 1;
        let slashee = validatorCandidates[slasheeIdx];

        for (let i = 0; i < misdemeanorThreshold - 1; i++) {
          await slashContract.connect(coinbase).slash(slashee.address);
        }
        let tx = slashContract.connect(coinbase).slash(slashee.address);

        await expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(slashee.address, SlashType.MISDEMEANOR, period);
        await expect(tx).to.emit(validatorContract, 'ValidatorPunished').withArgs(slashee.address, 0, 0);
      });
    });

    describe('Slash felony validator -- when the validators balance is sufficient after being slashed', async () => {
      let wrapUpEpochTx: ContractTransaction;
      let slashValidatorTx: ContractTransaction;
      let slasheeIdx: number;
      let slashee: SignerWithAddress;
      let slasheeInitStakingAmount: BigNumber;

      before(async () => {
        slasheeIdx = 2;
        slashee = validatorCandidates[slasheeIdx];
        slasheeInitStakingAmount = minValidatorBalance.add(slashFelonyAmount.mul(10));
        await stakingContract
          .connect(slashee)
          .applyValidatorCandidate(slashee.address, slashee.address, slashee.address, slashee.address, 2_00, {
            value: slasheeInitStakingAmount,
          });

        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(slasheeInitStakingAmount);

        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          await validatorContract.connect(coinbase).endPeriod();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        const currentBlock = await ethers.provider.getBlockNumber();
        period = await validatorContract.periodOf(currentBlock);

        expectingValidatorSet.push(slashee.address);
        expectingBlockProducerSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, expectingValidatorSet);

        expect(await validatorContract.getValidators()).eql(expectingValidatorSet);
        expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
      });

      it('Should the ValidatorSet contract emit event', async () => {
        for (let i = 0; i < felonyThreshold - 1; i++) {
          await slashContract.connect(coinbase).slash(slashee.address);
        }
        slashValidatorTx = await slashContract.connect(coinbase).slash(slashee.address);

        await expect(slashValidatorTx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(slashee.address, SlashType.FELONY, period);

        let blockNumber = await network.provider.send('eth_blockNumber');

        await expect(slashValidatorTx)
          .to.emit(validatorContract, 'ValidatorPunished')
          .withArgs(slashee.address, BigNumber.from(blockNumber).add(felonyJailBlocks), slashFelonyAmount);
      });

      it('Should the validator is put in jail', async () => {
        let blockNumber = await network.provider.send('eth_blockNumber');
        expect(await validatorContract.getJailUntils(expectingValidatorSet)).eql([
          BigNumber.from(blockNumber).add(felonyJailBlocks),
        ]);
      });

      it('Should the Staking contract emit Unstaked event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Unstaked')
          .withArgs(slashee.address, slashFelonyAmount);
      });

      it('Should the Staking contract subtract staked amount from validator', async () => {
        let _expectingSlasheeStakingAmount = slasheeInitStakingAmount.sub(slashFelonyAmount);
        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(_expectingSlasheeStakingAmount);
      });

      it('Should the block producer set exclude the jailed validator in the next epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingBlockProducerSet.pop();
        expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
        await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(wrapUpEpochTx!, expectingBlockProducerSet);
        expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });

      it('Should the validator cannot re-join as a block producer when jail time is not over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });

      it('Should the validator re-join as a block producer when jail time is over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingBlockProducerSet.push(slashee.address);

        expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
        await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(wrapUpEpochTx!, expectingBlockProducerSet);
        expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });
    });

    describe('Slash felony validator -- when the validators balance is equal to minimum balance', async () => {
      let wrapUpEpochTx: ContractTransaction;
      let slashValidatorTx: ContractTransaction;
      let slasheeIdx: number;
      let slashee: SignerWithAddress;
      let slasheeInitStakingAmount: BigNumber;

      before(async () => {
        slasheeIdx = 3;
        slashee = validatorCandidates[slasheeIdx];
        slasheeInitStakingAmount = minValidatorBalance;

        await stakingContract
          .connect(slashee)
          .applyValidatorCandidate(slashee.address, slashee.address, slashee.address, slashee.address, 2_00, {
            value: slasheeInitStakingAmount,
          });

        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(slasheeInitStakingAmount);

        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          await validatorContract.connect(coinbase).endPeriod();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        const currentBlock = await ethers.provider.getBlockNumber();
        period = await validatorContract.periodOf(currentBlock);

        expectingValidatorSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, expectingValidatorSet);

        expect(await validatorContract.getValidators()).eql(expectingValidatorSet);
      });

      describe('Check effects on indicator and staked amount', async () => {
        it('Should the ValidatorSet contract emit event', async () => {
          for (let i = 0; i < felonyThreshold - 1; i++) {
            await slashContract.connect(coinbase).slash(slashee.address);
          }
          slashValidatorTx = await slashContract.connect(coinbase).slash(slashee.address);

          await expect(slashValidatorTx)
            .to.emit(slashContract, 'UnavailabilitySlashed')
            .withArgs(slashee.address, SlashType.FELONY, period);

          let blockNumber = await network.provider.send('eth_blockNumber');

          await expect(slashValidatorTx)
            .to.emit(validatorContract, 'ValidatorPunished')
            .withArgs(slashee.address, BigNumber.from(blockNumber).add(felonyJailBlocks), slashFelonyAmount);
        });

        it('Should the validator is put in jail', async () => {
          let blockNumber = await network.provider.send('eth_blockNumber');
          expect(await validatorContract.getJailUntils([slashee.address])).eql([
            BigNumber.from(blockNumber).add(felonyJailBlocks),
          ]);
        });

        it('Should the Staking contract emit Unstaked event', async () => {
          await expect(slashValidatorTx)
            .to.emit(stakingContract, 'Unstaked')
            .withArgs(slashee.address, slashFelonyAmount);
        });

        it('Should the Staking contract subtract staked amount from validator', async () => {
          let _expectingSlasheeStakingAmount = slasheeInitStakingAmount.sub(slashFelonyAmount);
          expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(_expectingSlasheeStakingAmount);
        });
      });

      describe('Check effects on validator set and producer set', async () => {
        it('Should the block producer set exclude the jailed validator in the next epoch', async () => {
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });
          expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
          await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(wrapUpEpochTx!, expectingBlockProducerSet);
        });

        it('Should the validator cannot re-join as a block producer when jail time is not over', async () => {
          let _blockNumber = await network.provider.send('eth_blockNumber');
          let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
          let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

          await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
        });

        it('Should the validator can join as a validator when jail time is over, despite of insufficient fund', async () => {
          let _blockNumber = await network.provider.send('eth_blockNumber');
          let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
          let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

          await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });
          expectingBlockProducerSet.push(slashee.address);

          expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
          await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(wrapUpEpochTx!, expectingBlockProducerSet);
          expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
        });

        it.skip('Should the delegators cannot top-up for the under balance and to-be-kicked validator', async () => {
          // TODO:
        });
      });

      describe('Check effects on candidate list when the under balance candidates get kicked out', async () => {
        let expectingRevokedCandidates: Address[];
        it('Should the event of updating validator set emitted', async () => {
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            await validatorContract.connect(coinbase).endPeriod();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          expectingRevokedCandidates = expectingValidatorSet.slice(-1);
          expectingBlockProducerSet.pop();
          expectingValidatorSet.pop();

          await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, expectingValidatorSet);

          expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
          expect(await validatorContract.getValidators()).eql(expectingValidatorSet);
        });

        it('Should the event of revoking under balance candidates emitted', async () => {
          await CandidateManagerExpects.emitCandidatesRevokedEvent(wrapUpEpochTx, expectingRevokedCandidates);
        });

        it('Should the isValidatorCandidate method return false on kicked candidates', async () => {
          for (let _addr of expectingRevokedCandidates) {
            expect(await validatorContract.isValidatorCandidate(_addr)).eq(false);
          }
        });
      });

      describe('Kicked candidates re-join', async () => {
        it('Should the kicked validators cannot top-up, since they are not candidates anymore', async () => {
          let topUpTx = stakingContract.connect(slashee).stake(slashee.address, {
            value: slashFelonyAmount,
          });

          await expect(topUpTx).revertedWith('StakingManager: query for non-existent pool');
        });

        it('Should the kicked validator be able to re-join as a candidate', async () => {
          let applyCandidateTx = await stakingContract
            .connect(slashee)
            .applyValidatorCandidate(slashee.address, slashee.address, slashee.address, slashee.address, 2_00, {
              value: slasheeInitStakingAmount,
            });

          await CandidateManagerExpects.emitCandidateGrantedEvent(
            applyCandidateTx!,
            slashee.address,
            slashee.address,
            slashee.address,
            slashee.address
          );
        });
      });
    });
  });
});
