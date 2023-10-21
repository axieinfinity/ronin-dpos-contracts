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
} from '../../../src/types';

import { EpochController, expects as RoninValidatorSetExpects } from '../helpers/ronin-validator-set';
import { expects as CandidateManagerExpects } from '../helpers/candidate-manager';
import { mineBatchTxs } from '../helpers/utils';
import { SlashType } from '../../../src/script/slash-indicator';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { DEFAULT_ADDRESS } from '../../../src/utils';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

const jailDurationForUnavailabilityTier2Threshold = 28800 * 2;
const unavailabilityTier1Threshold = 10;
const unavailabilityTier2Threshold = 20;
const slashAmountForUnavailabilityTier2Threshold = BigNumber.from(10);
const slashDoubleSignAmount = 1000;
const minValidatorStakingAmount = BigNumber.from(100);
const waitingSecsToRevoke = 7 * 86400;
const maxValidatorNumber = 5;

describe('[Integration] Slash validators', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const { slashContractAddress, stakingContractAddress, validatorContractAddress, roninGovernanceAdminAddress, fastFinalityTrackingAddress } =
      await initTest('ActionSlashValidators')({
        slashIndicatorArguments: {
          unavailabilitySlashing: {
            unavailabilityTier1Threshold,
            unavailabilityTier2Threshold,
            slashAmountForUnavailabilityTier2Threshold,
            jailDurationForUnavailabilityTier2Threshold,
          },
          doubleSignSlashing: {
            slashDoubleSignAmount,
          },
        },
        roninValidatorSetArguments: {
          maxValidatorNumber,
        },
        stakingArguments: {
          minValidatorStakingAmount,
          waitingSecsToRevoke,
        },
        roninTrustedOrganizationArguments: {
          trustedOrganizations: [
            {
              consensusAddr: trustedOrgs[0].consensusAddr.address,
              governor: trustedOrgs[0].governor.address,
              bridgeVoter: trustedOrgs[0].bridgeVoter.address,
              weight: 100,
              addedBlock: 0,
            },
          ],
        },
      });

    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      trustedOrgs[0].governor
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initEpoch();
    await validatorContract.initializeV3(fastFinalityTrackingAddress);

    await EpochController.setTimestampToPeriodEnding();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    await mineBatchTxs(async () => {
      await validatorContract.endEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
    });
  });

  describe('Slash one validator', async () => {
    let expectingValidatorSet: Address[] = [];
    let expectingBlockProducerSet: Address[] = [];
    let period: BigNumberish;

    before(async () => {
      period = await validatorContract.currentPeriod();
      await validatorContract.addValidators([1, 2, 3].map((i) => validatorCandidates[i].consensusAddr.address));
    });

    describe('Slash misdemeanor validator', async () => {
      it('Should the ValidatorSet contract emit event', async () => {
        let slasheeIdx = 1;
        let slashee = validatorCandidates[slasheeIdx].consensusAddr;

        for (let i = 0; i < unavailabilityTier1Threshold - 1; i++) {
          await slashContract.connect(coinbase).slashUnavailability(slashee.address);
        }
        let tx = slashContract.connect(coinbase).slashUnavailability(slashee.address);

        await expect(tx)
          .to.emit(slashContract, 'Slashed')
          .withArgs(slashee.address, SlashType.UNAVAILABILITY_TIER_1, period);
        await expect(tx)
          .to.emit(validatorContract, 'ValidatorPunished')
          .withArgs(slashee.address, period, 0, 0, true, false);
      });
    });

    describe('Slash felony validator -- when the validators balance is sufficient after being slashed', async () => {
      let wrapUpEpochTx: ContractTransaction;
      let slashValidatorTx: ContractTransaction;
      let slasheeIdx: number;
      let slashee: ValidatorCandidateAddressSet;
      let slasheeInitStakingAmount: BigNumber;

      before(async () => {
        slasheeIdx = 2;
        slashee = validatorCandidates[slasheeIdx];
        slasheeInitStakingAmount = minValidatorStakingAmount.add(slashAmountForUnavailabilityTier2Threshold.mul(10));
        await stakingContract
          .connect(slashee.poolAdmin)
          .applyValidatorCandidate(
            slashee.candidateAdmin.address,
            slashee.consensusAddr.address,
            slashee.treasuryAddr.address,
            2_00,
            {
              value: slasheeInitStakingAmount,
            }
          );

        expect(await stakingContract.getStakingAmount(slashee.consensusAddr.address, slashee.poolAdmin.address)).eq(
          slasheeInitStakingAmount
        );

        await EpochController.setTimestampToPeriodEnding();
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        period = await validatorContract.currentPeriod();
        expectingValidatorSet.push(slashee.consensusAddr.address);
        expectingBlockProducerSet.push(slashee.consensusAddr.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, period, expectingValidatorSet);

        expect(await validatorContract.getValidators()).deep.equal(expectingValidatorSet);
        expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
      });

      it('Should the ValidatorSet contract emit event', async () => {
        for (let i = 0; i < unavailabilityTier2Threshold - 1; i++) {
          await slashContract.connect(coinbase).slashUnavailability(slashee.consensusAddr.address);
        }
        slashValidatorTx = await slashContract.connect(coinbase).slashUnavailability(slashee.consensusAddr.address);

        await expect(slashValidatorTx)
          .to.emit(slashContract, 'Slashed')
          .withArgs(slashee.consensusAddr.address, SlashType.UNAVAILABILITY_TIER_2, period);

        let blockNumber = await network.provider.send('eth_blockNumber');

        await expect(slashValidatorTx)
          .to.emit(validatorContract, 'ValidatorPunished')
          .withArgs(
            slashee.consensusAddr.address,
            period,
            BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold),
            slashAmountForUnavailabilityTier2Threshold,
            true,
            false
          );
      });

      it('Should the validator is put in jail', async () => {
        let blockNumber = await network.provider.send('eth_blockNumber');
        // await compareBigNumbers(await validatorContract.getJailUntils(expectingValidatorSet), [
        //   BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold),
        // ]);

        expect(await validatorContract.getJailUntils(expectingValidatorSet)).deep.equal([
          BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold),
        ]);
      });

      it('Should the Staking contract emit Unstaked event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Unstaked')
          .withArgs(slashee.consensusAddr.address, slashAmountForUnavailabilityTier2Threshold);
      });

      it('Should the Staking contract subtract staking amount from validator', async () => {
        let _expectingSlasheeStakingAmount = slasheeInitStakingAmount.sub(slashAmountForUnavailabilityTier2Threshold);
        expect(await stakingContract.getStakingAmount(slashee.consensusAddr.address, slashee.poolAdmin.address)).eq(
          _expectingSlasheeStakingAmount
        );
      });

      it('Should the block producer set exclude the jailed validator in the next epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingBlockProducerSet.pop();
        expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
        await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
          wrapUpEpochTx!,
          period,
          await validatorContract.epochOf((await ethers.provider.getBlockNumber()) + 1),
          expectingBlockProducerSet
        );
        await expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });

      it('Should the validator cannot re-join as a block producer when jail time is not over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.consensusAddr.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString(), '0x0']);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        await expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });

      it('Should the validator re-join as a block producer when jail time is over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.consensusAddr.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString(), '0x0']);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingBlockProducerSet.push(slashee.consensusAddr.address);

        expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
        await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
          wrapUpEpochTx!,
          period,
          await validatorContract.epochOf((await ethers.provider.getBlockNumber()) + 1),
          expectingBlockProducerSet
        );
        await expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
      });
    });

    describe('Slash felony validator -- when the validators balance is equal to minimum balance', async () => {
      let wrapUpEpochTx: ContractTransaction;
      let slashValidatorTxs: (ContractTransaction | undefined)[];
      let slasheeIdxs: number[];
      let slashees: ValidatorCandidateAddressSet[];
      let slasheeInitStakingAmount: BigNumber;
      let expectingRevokedCandidates: Address[];

      before(async () => {
        slasheeIdxs = [3, 4];
        slashValidatorTxs = slasheeIdxs.map((v) => undefined);
        slashees = slasheeIdxs.map((idx) => validatorCandidates[idx]);
        slasheeInitStakingAmount = minValidatorStakingAmount;

        for (let i = 0; i < slashees.length; i++) {
          await stakingContract
            .connect(slashees[i].poolAdmin)
            .applyValidatorCandidate(
              slashees[i].candidateAdmin.address,
              slashees[i].consensusAddr.address,
              slashees[i].treasuryAddr.address,
              2_00,
              {
                value: slasheeInitStakingAmount.add(slashees.length - i),
              }
            );
          expect(
            await stakingContract.getStakingAmount(slashees[i].consensusAddr.address, slashees[i].poolAdmin.address)
          ).eq(slasheeInitStakingAmount.add(slashees.length - i));
        }

        await EpochController.setTimestampToPeriodEnding();
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        for (let i = 0; i < slashees.length; i++) {
          expectingValidatorSet.push(slashees[i].consensusAddr.address);
        }

        period = await validatorContract.currentPeriod();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, period, expectingValidatorSet);
        expect(await validatorContract.getValidators()).deep.equal(expectingValidatorSet);
      });

      describe('Check effects on indicator and staking amount', async () => {
        it('Should the ValidatorSet contract emit event when the validators are slashed tier-2', async () => {
          for (let i = 0; i < unavailabilityTier2Threshold - 1; i++) {
            for (let j = 0; j < slashees.length; j++) {
              await slashContract.connect(coinbase).slashUnavailability(slashees[j].consensusAddr.address);
            }
          }

          for (let j = 0; j < slashees.length; j++) {
            slashValidatorTxs[j] = await slashContract
              .connect(coinbase)
              .slashUnavailability(slashees[j].consensusAddr.address);
            await expect(slashValidatorTxs[j])
              .to.emit(slashContract, 'Slashed')
              .withArgs(slashees[j].consensusAddr.address, SlashType.UNAVAILABILITY_TIER_2, period);
            const blockNumber = await network.provider.send('eth_blockNumber');
            await expect(slashValidatorTxs[j])
              .to.emit(validatorContract, 'ValidatorPunished')
              .withArgs(
                slashees[j].consensusAddr.address,
                period,
                BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold),
                slashAmountForUnavailabilityTier2Threshold,
                true,
                false
              );
          }
        });

        it('Should the validators are put in jail', async () => {
          const blockNumber = await network.provider.send('eth_blockNumber');
          expect(await validatorContract.getJailUntils(slashees.map((v) => v.consensusAddr.address))).deep.equal([
            BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold).sub(1),
            BigNumber.from(blockNumber).add(jailDurationForUnavailabilityTier2Threshold).sub(0),
          ]);
        });

        it('Should the Staking contract emit Unstaked event', async () => {
          for (let j = 0; j < slashees.length; j++) {
            await expect(slashValidatorTxs[j])
              .to.emit(stakingContract, 'Unstaked')
              .withArgs(slashees[j].consensusAddr.address, slashAmountForUnavailabilityTier2Threshold);
          }
        });

        it('Should the Staking contract subtract staking amount from validator', async () => {
          for (let j = 0; j < slashees.length; j++) {
            let expectingSlasheeStakingAmount = slasheeInitStakingAmount
              .sub(slashAmountForUnavailabilityTier2Threshold)
              .add(slashees.length - j);
            expect(
              await stakingContract.getStakingAmount(slashees[j].consensusAddr.address, slashees[j].poolAdmin.address)
            ).eq(expectingSlasheeStakingAmount);
          }
        });
      });

      describe('Check effects on validator set and producer set', async () => {
        it('Should the block producer set exclude the jailed validators in the next epoch', async () => {
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });
          expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
          await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
            wrapUpEpochTx!,
            period,
            await validatorContract.epochOf((await ethers.provider.getBlockNumber()) + 1),
            expectingBlockProducerSet
          );
        });

        it('Should the validator cannot re-join as a block producer when jail time is not over', async () => {
          let _blockNumber = await network.provider.send('eth_blockNumber');
          let _jailUntil = await validatorContract.getJailUntils([slashees[0].consensusAddr.address]);
          let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

          await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString(), '0x0']);
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          await expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
        });

        it('Should the validator can join as a validator when jail time is over, despite of insufficient fund', async () => {
          let _blockNumber = await network.provider.send('eth_blockNumber');
          let _jailUntil = await validatorContract.getJailUntils([slashees[slashees.length - 1].consensusAddr.address]);
          let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

          await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          slashees.forEach((slashee) => expectingBlockProducerSet.push(slashee.consensusAddr.address));
          expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
          expect(await validatorContract.getValidators()).deep.equal(expectingBlockProducerSet);
          await RoninValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
            wrapUpEpochTx!,
            period,
            await validatorContract.epochOf((await ethers.provider.getBlockNumber()) + 1),
            expectingBlockProducerSet
          );
          await expect(wrapUpEpochTx).not.emit(validatorContract, 'ValidatorSetUpdated');
        });
      });

      describe('Check effects on candidate list when the under balance candidates get kicked out', async () => {
        it('Should be able to emit the deadline events for insufficient staking amount validators', async () => {
          await EpochController.setTimestampToPeriodEnding();
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          const receipt = await wrapUpEpochTx!.wait();
          const block = await ethers.provider.getBlock(receipt.blockNumber);
          const deadline = waitingSecsToRevoke + block.timestamp;
          for (let j = 0; j < slashees.length; j++) {
            await expect(wrapUpEpochTx)
              .emit(validatorContract, 'CandidateTopupDeadlineUpdated')
              .withArgs(slashees[j].consensusAddr.address, deadline);
          }

          period = await validatorContract.currentPeriod();
          await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, period, expectingValidatorSet);
          expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
          expect(await validatorContract.getValidators()).deep.equal(expectingValidatorSet);
        });

        it('The validator should be able to top up before deadline', async () => {
          await stakingContract
            .connect(slashees[0].poolAdmin)
            .stake(slashees[0].consensusAddr.address, { value: slashAmountForUnavailabilityTier2Threshold });
        });

        it('Should be able to emit event for clearing deadline', async () => {
          await EpochController.setTimestampToPeriodEnding();
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });
          await expect(wrapUpEpochTx)
            .emit(validatorContract, 'CandidateTopupDeadlineUpdated')
            .withArgs(slashees[0].consensusAddr.address, 0);
        });

        it('Should be able to kick validators which are unsatisfied staking amount condition', async () => {
          await network.provider.send('evm_increaseTime', [waitingSecsToRevoke]);
          await EpochController.setTimestampToPeriodEnding();
          await mineBatchTxs(async () => {
            await validatorContract.connect(coinbase).endEpoch();
            wrapUpEpochTx = await validatorContract.connect(coinbase).wrapUpEpoch();
          });

          expectingRevokedCandidates = expectingValidatorSet.slice(-1);
          expectingBlockProducerSet.pop();
          expectingValidatorSet.pop();
          period = await validatorContract.currentPeriod();

          await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(wrapUpEpochTx!, period, expectingValidatorSet);
          expect(await validatorContract.getBlockProducers()).deep.equal(expectingBlockProducerSet);
          expect(await validatorContract.getValidators()).deep.equal(expectingValidatorSet);
        });

        it('Should the event of revoking under balance candidates emitted', async () => {
          await CandidateManagerExpects.emitCandidatesRevokedEvent(wrapUpEpochTx, expectingRevokedCandidates);
        });

        it('Should the pending reward of the kicked validator get auto claimed', async () => {
          for (let _addr of expectingRevokedCandidates) {
            let _validator = validatorCandidates.find((_) => _.consensusAddr.address == _addr);
            await expect(wrapUpEpochTx)
              .emit(stakingContract, 'RewardClaimed')
              .withArgs(_addr, _validator!.poolAdmin.address, 0);
          }
        });

        it('Should the isValidatorCandidate method return false on kicked candidates', async () => {
          for (let addr of expectingRevokedCandidates) {
            await expect(await validatorContract.isValidatorCandidate(addr)).to.false;
          }
        });
      });

      describe('Kicked candidates re-join', async () => {
        before(() => {
          slashees = slashees.filter((s) => expectingRevokedCandidates.includes(s.consensusAddr.address));
        });

        it('Should the kicked validators cannot top-up, since they are not candidates anymore', async () => {
          for (let slashee of slashees) {
            const topUpTx = stakingContract.connect(slashee.poolAdmin).stake(slashee.consensusAddr.address, {
              value: slashAmountForUnavailabilityTier2Threshold,
            });
            await expect(topUpTx)
              .revertedWithCustomError(stakingContract, 'ErrInactivePool')
              .withArgs(slashee.consensusAddr.address);
          }
        });

        it('Should the kicked validator be able to re-join as a candidate', async () => {
          for (let slashee of slashees) {
            let applyCandidateTx = await stakingContract
              .connect(slashee.poolAdmin)
              .applyValidatorCandidate(
                slashee.candidateAdmin.address,
                slashee.consensusAddr.address,
                slashee.treasuryAddr.address,
                2_00,
                {
                  value: slasheeInitStakingAmount,
                }
              );

            await CandidateManagerExpects.emitCandidateGrantedEvent(
              applyCandidateTx!,
              slashee.consensusAddr.address,
              slashee.treasuryAddr.address,
              slashee.candidateAdmin.address
            );
          }
        });
      });
    });
  });
});
