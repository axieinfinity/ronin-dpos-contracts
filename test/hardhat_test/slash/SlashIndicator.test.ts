import { BigNumber, BytesLike } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockRoninValidatorSetOverridePrecompile__factory,
  MockSlashIndicatorExtended,
  MockSlashIndicatorExtended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  RoninValidatorSet,
  Staking,
  Staking__factory,
} from '../../../src/types';
import { SlashType } from '../../../src/script/slash-indicator';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
import { IndicatorController } from '../helpers/slash';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { getLastBlockTimestamp } from '../helpers/utils';
import { ProposalDetailStruct } from '../../../src/types/GovernanceAdmin';
import { getProposalHash, VoteType } from '../../../src/script/proposal';
import { expects as GovernanceAdminExpects } from '../helpers/governance-admin';
import { Encoder } from '../helpers/encoder';

let slashContract: MockSlashIndicatorExtended;
let mockSlashLogic: MockSlashIndicatorExtended;
let stakingContract: Staking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let validatorContract: RoninValidatorSet;
let vagabond: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

let localIndicators: IndicatorController;
let localEpochController: EpochController;

const unavailabilityTier1Threshold = 5;
const unavailabilityTier2Threshold = 10;
const maxValidatorNumber = 21;
const maxValidatorCandidate = 50;
const numberOfBlocksInEpoch = 600;
const minValidatorStakingAmount = BigNumber.from(100);

const slashAmountForUnavailabilityTier2Threshold = BigNumber.from(2);
const jailDurationForUnavailabilityTier2Threshold = 28800 * 2;
const slashDoubleSignAmount = BigNumber.from(5);

const missingVotesRatioTier1 = 10_00; // 10%
const missingVotesRatioTier2 = 20_00; // 20%
const jailDurationForMissingVotesRatioTier2 = 28800 * 2;
const skipBridgeOperatorSlashingThreshold = 10;
const bridgeVotingThreshold = 28800 * 3;
const bridgeVotingSlashAmount = BigNumber.from(10).pow(18).mul(10_000);

const minOffsetToStartSchedule = 200;
const proposalExpiryDuration = 60;

const validateIndicatorAt = async (idx: number) => {
  expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[idx].consensusAddr.address)).to.eq(
    localIndicators.getAt(idx)
  );
};

describe('Slash indicator test', () => {
  before(async () => {
    [deployer, coinbase, vagabond, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    const {
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
      fastFinalityTrackingAddress,
    } = await initTest('SlashIndicator')({
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
        bridgeOperatorSlashing: {
          missingVotesRatioTier1,
          missingVotesRatioTier2,
          jailDurationForMissingVotesRatioTier2,
          skipBridgeOperatorSlashingThreshold,
        },
        bridgeVotingSlashing: {
          bridgeVotingThreshold,
          bridgeVotingSlashAmount,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        numberOfBlocksInEpoch,
        maxValidatorCandidate,
      },
      maintenanceArguments: {
        minOffsetToStartSchedule,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
      governanceAdminArguments: {
        proposalExpiryDuration,
      },
      bridgeManagerArguments: {
        numerator: 70,
        denominator: 100,
        members: [],
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetOverridePrecompile__factory.connect(validatorContractAddress, deployer);
    slashContract = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetOverridePrecompile__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initializeV3(fastFinalityTrackingAddress);

    mockSlashLogic = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashLogic.deployed();
    await governanceAdminInterface.upgrade(slashContractAddress, mockSlashLogic.address);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          1,
          { value: minValidatorStakingAmount.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    localEpochController = new EpochController(minOffsetToStartSchedule, numberOfBlocksInEpoch);
    await localEpochController.mineToBeforeEndOfEpoch(2);
    await validatorContract.connect(coinbase).wrapUpEpoch();
    expect(await validatorContract.getValidators()).deep.equal(validatorCandidates.map((_) => _.consensusAddr.address));

    localIndicators = new IndicatorController(validatorCandidates.length);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Config test', async () => {
    it('Should configs of unavailability are set correctly', async () => {
      let configs = await slashContract.getUnavailabilitySlashingConfigs();
      expect(configs.unavailabilityTier1Threshold_).eq(
        unavailabilityTier1Threshold,
        'wrong unavailability tier 1 config'
      );
      expect(configs.unavailabilityTier2Threshold_).eq(
        unavailabilityTier2Threshold,
        'wrong unavailability tier 2 config'
      );
      expect(configs.slashAmountForUnavailabilityTier2Threshold_).eq(
        slashAmountForUnavailabilityTier2Threshold,
        'slash amount tier 2 config'
      );
      expect(configs.jailDurationForUnavailabilityTier2Threshold_).eq(
        jailDurationForUnavailabilityTier2Threshold,
        'jail duration tier 2 config'
      );
    });

    it('Should configs of double signing are set correctly', async () => {
      let configs = await slashContract.getDoubleSignSlashingConfigs();
      expect(configs.slashDoubleSignAmount_).eq(slashDoubleSignAmount, 'wrong double sign config');
    });

    it('Should configs of bridge operator slash are set correctly', async () => {
      let configs = await slashContract.getBridgeOperatorSlashingConfigs();
      expect(configs.missingVotesRatioTier1_).eq(missingVotesRatioTier1, 'wrong missing votes ratio tier 1 config');
      expect(configs.missingVotesRatioTier2_).eq(missingVotesRatioTier2, 'wrong missing votes ratio tier 2 config');
      expect(configs.jailDurationForMissingVotesRatioTier2_).eq(
        jailDurationForMissingVotesRatioTier2,
        'wrong jail duration for vote tier 2 config'
      );
      expect(configs.skipBridgeOperatorSlashingThreshold_).eq(
        skipBridgeOperatorSlashingThreshold,
        'wrong skip slashing config'
      );
    });

    it('Should configs of bridge voting slash are set correctly', async () => {
      let configs = await slashContract.getBridgeVotingSlashingConfigs();
      expect(configs.bridgeVotingSlashAmount_).eq(bridgeVotingSlashAmount, 'wrong bridge voting slash amount config');
      expect(configs.bridgeVotingThreshold_).eq(bridgeVotingThreshold, 'wrong bridge voting threshold config');
    });
  });

  describe('Single flow test', async () => {
    describe('Unauthorized test', async () => {
      it('Should non-coinbase cannot call slash', async () => {
        await expect(
          slashContract.connect(vagabond).slashUnavailability(validatorCandidates[0].consensusAddr.address)
        ).to.revertedWithCustomError(slashContract, 'ErrUnauthorized');
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        let tx = await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        await expect(tx).to.not.emit(slashContract, 'Slashed');
        localIndicators.setAt(slasheeIdx, 1);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        const slasherIdx = 0;
        await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasherIdx].consensusAddr.address);

        localIndicators.resetAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        let tx = slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        await expect(tx).to.be.revertedWithCustomError(
          slashContract,
          'ErrCannotSlashAValidatorTwiceOrSlashMoreThanOneValidatorInOneBlock'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        localIndicators.increaseAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not able to slash more than one validator in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx1 = 1;
        const slasheeIdx2 = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx1].consensusAddr.address);
        let tx = slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx2].consensusAddr.address);
        await expect(tx).to.be.revertedWithCustomError(
          slashContract,
          'ErrCannotSlashAValidatorTwiceOrSlashMoreThanOneValidatorInOneBlock'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        localIndicators.increaseAt(slasheeIdx1);
        await validateIndicatorAt(slasheeIdx1);
        localIndicators.setAt(slasheeIdx2, 1);
        await validateIndicatorAt(slasheeIdx1);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for misdemeanor (slash tier-1)', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        for (let i = 0; i < unavailabilityTier1Threshold; i++) {
          tx = await slashContract
            .connect(validatorCandidates[slasherIdx].consensusAddr)
            .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        }

        let period = await validatorContract.currentPeriod();
        await expect(tx)
          .to.emit(slashContract, 'Slashed')
          .withArgs(validatorCandidates[slasheeIdx].consensusAddr.address, SlashType.UNAVAILABILITY_TIER_1, period);
        localIndicators.setAt(slasheeIdx, unavailabilityTier1Threshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter is in between misdemeanor (tier-1) and felony (tier-2) thresholds', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        tx = await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        localIndicators.increaseAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        await expect(tx).not.to.emit(slashContract, 'Slashed');
      });

      it('Should sync with validator set for felony (slash tier-2)', async () => {
        let tx;
        const slasherIdx = 0;
        const slasheeIdx = 4;

        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        let period = await validatorContract.currentPeriod();

        for (let i = 0; i < unavailabilityTier2Threshold; i++) {
          tx = await slashContract
            .connect(validatorCandidates[slasherIdx].consensusAddr)
            .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);

          if (i == unavailabilityTier1Threshold - 1) {
            await expect(tx)
              .to.emit(slashContract, 'Slashed')
              .withArgs(validatorCandidates[slasheeIdx].consensusAddr.address, SlashType.UNAVAILABILITY_TIER_1, period);
          }
        }

        await expect(tx)
          .to.emit(slashContract, 'Slashed')
          .withArgs(validatorCandidates[slasheeIdx].consensusAddr.address, SlashType.UNAVAILABILITY_TIER_2, period);
        localIndicators.setAt(slasheeIdx, unavailabilityTier2Threshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter exceeds felony threshold (tier-2) ', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        tx = await slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        localIndicators.increaseAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        await expect(tx).not.to.emit(slashContract, 'Slashed');
      });
    });

    describe('Resetting counter', async () => {
      it('Should the counter reset for one validator when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 5;
        let numberOfSlashing = unavailabilityTier2Threshold - 1;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          await slashContract
            .connect(validatorCandidates[slasherIdx].consensusAddr)
            .slashUnavailability(validatorCandidates[slasheeIdx].consensusAddr.address);
        }

        localIndicators.setAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await EpochController.setTimestampToPeriodEnding();
        await localEpochController.mineToBeforeEndOfEpoch();
        await validatorContract.connect(validatorCandidates[slasherIdx].consensusAddr).wrapUpEpoch();

        localIndicators.resetAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should the counter reset for multiple validators when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdxs = [6, 7, 8, 9, 10];
        let numberOfSlashing = unavailabilityTier2Threshold - 1;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          for (let j = 0; j < slasheeIdxs.length; j++) {
            await slashContract
              .connect(validatorCandidates[slasherIdx].consensusAddr)
              .slashUnavailability(validatorCandidates[slasheeIdxs[j]].consensusAddr.address);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          localIndicators.setAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await EpochController.setTimestampToPeriodEnding();
        await localEpochController.mineToBeforeEndOfEpoch();
        await validatorContract.connect(validatorCandidates[slasherIdx].consensusAddr).wrapUpEpoch();

        for (let j = 0; j < slasheeIdxs.length; j++) {
          localIndicators.resetAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });

    describe('Double signing slash', async () => {
      let header1: BytesLike;
      let header2: BytesLike;

      it('Should not be able to slash themselves (only admin allowed)', async () => {
        const slasherIdx = 0;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[slasherIdx].consensusAddr.address]);

        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

        let tx = slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashDoubleSign(validatorCandidates[slasherIdx].consensusAddr.address, header1, header2);

        await expect(tx).revertedWithCustomError(slashContract, 'ErrUnauthorized');
      });

      it('Should non-admin not be able to slash validator with double signing', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;
        const coinbaseIdx = 2;
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[coinbaseIdx].consensusAddr.address]);

        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

        let tx = slashContract
          .connect(validatorCandidates[slasherIdx].consensusAddr)
          .slashDoubleSign(validatorCandidates[slasheeIdx].consensusAddr.address, header1, header2);

        await expect(tx).revertedWithCustomError(slashContract, 'ErrUnauthorized');
      });

      it('Should be able to slash validator with double signing', async () => {
        const slasheeIdx = 1;
        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader2');

        const latestTimestamp = await getLastBlockTimestamp();
        let calldata = governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          slashContract.interface.encodeFunctionData('slashDoubleSign', [
            validatorCandidates[slasheeIdx].consensusAddr.address,
            header1,
            header2,
          ]),
        ]);
        let proposal: ProposalDetailStruct = await governanceAdminInterface.createProposal(
          latestTimestamp + proposalExpiryDuration,
          slashContract.address,
          0,
          calldata,
          500_000
        );
        let signatures = await governanceAdminInterface.generateSignatures(
          proposal,
          trustedOrgs.map((_) => _.governor)
        );
        let supports = signatures.map(() => VoteType.For);

        let tx = await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .proposeProposalStructAndCastVotes(proposal, supports, signatures);

        expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address))
          .to.true;
        await expect(tx).emit(governanceAdmin, 'ProposalExecuted');

        let period = await validatorContract.currentPeriod();

        await expect(tx)
          .to.emit(slashContract, 'Slashed')
          .withArgs(validatorCandidates[slasheeIdx].consensusAddr.address, SlashType.DOUBLE_SIGNING, period);
      });

      it('Should not be able to slash validator with already submitted evidence', async () => {
        const slasheeIdx = 1;
        header1 = ethers.utils.toUtf8Bytes('sampleHeader1');
        header2 = ethers.utils.toUtf8Bytes('sampleHeaderNew');

        const latestTimestamp = await getLastBlockTimestamp();
        let calldata = governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          slashContract.interface.encodeFunctionData('slashDoubleSign', [
            validatorCandidates[slasheeIdx].consensusAddr.address,
            header1,
            header2,
          ]),
        ]);
        let proposal: ProposalDetailStruct = await governanceAdminInterface.createProposal(
          latestTimestamp + proposalExpiryDuration,
          slashContract.address,
          0,
          calldata,
          500_000
        );
        let proposalHash = getProposalHash(proposal);
        let signatures = await governanceAdminInterface.generateSignatures(
          proposal,
          trustedOrgs.map((_) => _.governor)
        );
        let supports = signatures.map(() => VoteType.For);

        let tx = await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .proposeProposalStructAndCastVotes(proposal, supports, signatures);

        expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address))
          .to.true;
        await expect(tx).emit(governanceAdmin, 'ProposalExecuted');

        await GovernanceAdminExpects.emitProposalExecutedEvent(
          tx,
          proposalHash,
          [false],
          [slashContract.interface.getSighash(slashContract.interface.getError('ErrEvidenceAlreadySubmitted'))]
        );
      });

      it('Should be able to slash non-validator with double signing', async () => {
        const slasheeAddr = signers[1].address;
        header1 = ethers.utils.toUtf8Bytes('sampleHeader3');
        header2 = ethers.utils.toUtf8Bytes('sampleHeader4');

        const latestTimestamp = await getLastBlockTimestamp();
        let calldata = governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          slashContract.interface.encodeFunctionData('slashDoubleSign', [slasheeAddr, header1, header2]),
        ]);
        let proposal: ProposalDetailStruct = await governanceAdminInterface.createProposal(
          latestTimestamp + proposalExpiryDuration,
          slashContract.address,
          0,
          calldata,
          500_000
        );
        let signatures = await governanceAdminInterface.generateSignatures(
          proposal,
          trustedOrgs.map((_) => _.governor)
        );
        let supports = signatures.map(() => VoteType.For);

        let tx = await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .proposeProposalStructAndCastVotes(proposal, supports, signatures);

        expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address))
          .to.true;
        await expect(tx).emit(governanceAdmin, 'ProposalExecuted');
        let period = await validatorContract.currentPeriod();

        await expect(tx).to.emit(slashContract, 'Slashed').withArgs(slasheeAddr, SlashType.DOUBLE_SIGNING, period);
      });
    });
  });
});
