import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  Staking,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  Staking__factory,
  MockSlashIndicatorExtended__factory,
  MockSlashIndicatorExtended,
  RoninGovernanceAdmin__factory,
  RoninGovernanceAdmin,
  StakingVesting__factory,
  StakingVesting,
  TransparentUpgradeableProxyV2__factory,
} from '../../../src/types';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';
import { getLastBlockTimestamp, mineBatchTxs } from '../helpers/utils';
import { defaultTestConfig, initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { Address } from 'hardhat-deploy/dist/types';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { VoteType } from '../../../src/script/proposal';
import {
  ValidatorCandidateAddressSet,
  createManyValidatorCandidateAddressSets,
} from '../helpers/address-set-types/validator-candidate-set-type';
import {
  WhitelistedCandidateAddressSet,
  mergeToManyWhitelistedCandidateAddressSets,
} from '../helpers/address-set-types/whitelisted-candidate-set-type';

let roninValidatorSet: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let poolAdmin: SignerWithAddress;
let candidateAdmin: SignerWithAddress;
let consensusAddr: SignerWithAddress;
let treasury: SignerWithAddress;
let bridgeOperator: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];
let whitelistedCandidates: WhitelistedCandidateAddressSet[];

let currentValidatorSet: string[];
let lastPeriod: BigNumber;
let epoch: BigNumber;

const localValidatorCandidatesLength = 6;
const localTrustedOrgsLength = 1;

const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 1;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const blockProducerBonusPerBlock = BigNumber.from(5000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);
const zeroTopUpAmount = 0;
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const maxCommissionRate = 30_00; // 30%
const defaultMinCommissionRate = 0;

describe('Ronin Validator Set: candidate test', () => {
  before(async () => {
    [poolAdmin, consensusAddr, bridgeOperator, deployer, ...signers] = await ethers.getSigners();
    candidateAdmin = poolAdmin;
    treasury = poolAdmin;

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, localTrustedOrgsLength * 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(
      signers.splice(0, localValidatorCandidatesLength * 3)
    );
    whitelistedCandidates = mergeToManyWhitelistedCandidateAddressSets([trustedOrgs[0]], [validatorCandidates[0]]);

    await network.provider.send('hardhat_setCoinbase', [consensusAddr.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
      fastFinalityTrackingAddress,
    } = await initTest('RoninValidatorSet-Candidate')({
      slashIndicatorArguments: {
        doubleSignSlashing: {
          slashDoubleSignAmount,
        },
        unavailabilitySlashing: {
          slashAmountForUnavailabilityTier2Threshold,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
        maxCommissionRate,
      },
      stakingVestingArguments: {
        blockProducerBonusPerBlock,
        bridgeOperatorBonusPerBlock,
        topupAmount: zeroTopUpAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
        maxValidatorCandidate,
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
    });

    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);
    await roninValidatorSet.initEpoch();
    await roninValidatorSet.initializeV3(fastFinalityTrackingAddress);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Apply candidate', async () => {
    let expectingValidatorsAddr: Address[];
    it('Should normal user can apply for candidate and the set get synced', async () => {
      for (let i = 1; i < 5; i++) {
        await stakingContract
          .connect(validatorCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            validatorCandidates[i].candidateAdmin.address,
            validatorCandidates[i].consensusAddr.address,
            validatorCandidates[i].treasuryAddr.address,
            2_00,
            {
              value: minValidatorStakingAmount.add(i),
            }
          );
      }

      let tx: ContractTransaction;
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      expectingValidatorsAddr = validatorCandidates
        .slice(1, 5)
        .reverse()
        .map((_) => _.consensusAddr.address);

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, expectingValidatorsAddr);
      expect(await roninValidatorSet.getValidators()).deep.equal(expectingValidatorsAddr);
      expect(await roninValidatorSet.getBlockProducers()).deep.equal(expectingValidatorsAddr);
    });

    it('Should trusted org can apply for candidate and the set get synced', async () => {
      for (let i = 0; i < 1; i++) {
        await stakingContract
          .connect(whitelistedCandidates[i].poolAdmin)
          .applyValidatorCandidate(
            whitelistedCandidates[i].candidateAdmin.address,
            whitelistedCandidates[i].consensusAddr.address,
            whitelistedCandidates[i].treasuryAddr.address,
            2_00,
            {
              value: minValidatorStakingAmount.add(i),
            }
          );
      }

      let tx: ContractTransaction;
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      epoch = await roninValidatorSet.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await roninValidatorSet.currentPeriod();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(consensusAddr).wrapUpEpoch();
      });

      expectingValidatorsAddr = validatorCandidates
        .slice(2, 5)
        .reverse()
        .map((_) => _.consensusAddr.address);
      expectingValidatorsAddr = [whitelistedCandidates[0].consensusAddr.address, ...expectingValidatorsAddr];

      await expect(tx!).emit(roninValidatorSet, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await roninValidatorSet.currentPeriod();
      await RoninValidatorSet.expects.emitValidatorSetUpdatedEvent(tx!, lastPeriod, expectingValidatorsAddr);
      expect(await roninValidatorSet.getValidators()).deep.equal(expectingValidatorsAddr);
      expect(await roninValidatorSet.getBlockProducers()).deep.equal(expectingValidatorsAddr);
    });
  });

  describe('Grant validator candidate sanity check', async () => {
    it('Should not be able to apply for candidate role with existed pool admin address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[4].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[4].candidateAdmin.address,
          validatorCandidates[4].consensusAddr.address,
          validatorCandidates[4].treasuryAddr.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx)
        .revertedWithCustomError(stakingContract, 'ErrAdminOfAnyActivePoolForbidden')
        .withArgs(validatorCandidates[4].poolAdmin.address);
    });

    it('Should not be able to apply for candidate role with existed candidate admin address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[5].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[0].candidateAdmin.address,
          validatorCandidates[5].consensusAddr.address,
          validatorCandidates[5].treasuryAddr.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWithCustomError(stakingContract, 'ErrThreeInteractionAddrsNotEqual');
    });

    it('Should not be able to apply for candidate role with existed treasury address', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[5].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[5].candidateAdmin.address,
          validatorCandidates[5].consensusAddr.address,
          validatorCandidates[0].treasuryAddr.address,
          2_00,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWithCustomError(stakingContract, 'ErrThreeInteractionAddrsNotEqual');
    });

    it('Should not be able to apply for candidate role with commission rate higher than allowed', async () => {
      let tx = stakingContract
        .connect(validatorCandidates[5].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[5].candidateAdmin.address,
          validatorCandidates[5].consensusAddr.address,
          validatorCandidates[5].treasuryAddr.address,
          maxCommissionRate + 1,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWithCustomError(stakingContract, 'ErrInvalidCommissionRate');
    });
    it('Should not be able to apply for candidate role with commission rate lower than allowed', async () => {
      const minCommissionRate = 10_00;
      const proposalChanging = await governanceAdminInterface.createProposal(
        (await getLastBlockTimestamp()) +
          BigNumber.from(defaultTestConfig.governanceAdminArguments?.proposalExpiryDuration).toNumber(),
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setCommissionRateRange', [
            minCommissionRate,
            maxCommissionRate,
          ]),
        ]),
        500_000
      );
      const signaturesOfChangingProposal = await governanceAdminInterface.generateSignatures(proposalChanging);
      const supportsOfSignatureChanging = signaturesOfChangingProposal.map(() => VoteType.For);
      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(proposalChanging, supportsOfSignatureChanging, signaturesOfChangingProposal);
      let tx = stakingContract
        .connect(validatorCandidates[5].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[5].candidateAdmin.address,
          validatorCandidates[5].consensusAddr.address,
          validatorCandidates[5].treasuryAddr.address,
          minCommissionRate - 1,
          {
            value: minValidatorStakingAmount,
          }
        );

      await expect(tx).revertedWithCustomError(stakingContract, 'ErrInvalidCommissionRate');
      const proposalRecover = await governanceAdminInterface.createProposal(
        (await getLastBlockTimestamp()) +
          BigNumber.from(defaultTestConfig.governanceAdminArguments?.proposalExpiryDuration).toNumber(),
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setCommissionRateRange', [
            defaultMinCommissionRate,
            maxCommissionRate,
          ]),
        ]),
        500_000
      );
      const signaturesOfRecoverProposal = await governanceAdminInterface.generateSignatures(proposalRecover);
      const supportsOfSignaturesRecover = signaturesOfRecoverProposal.map(() => VoteType.For);
      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(proposalRecover, supportsOfSignaturesRecover, signaturesOfRecoverProposal);
    });
  });

  describe('Renounce candidate', async () => {
    it('Should trusted org not be able to renounce candidate role', async () => {
      await expect(
        stakingContract
          .connect(whitelistedCandidates[0].poolAdmin)
          .requestRenounce(whitelistedCandidates[0].consensusAddr.address)
      ).revertedWithCustomError(roninValidatorSet, 'ErrTrustedOrgCannotRenounce');
    });

    it('Should normal candidate be able to request renounce', async () => {
      expect(
        await stakingContract
          .connect(validatorCandidates[1].poolAdmin)
          .requestRenounce(validatorCandidates[1].consensusAddr.address)
      )
        .emit(roninValidatorSet, 'CandidateRevokingTimestampUpdated')
        .withArgs(validatorCandidates[1].consensusAddr.address, anyValue);
    });
  });
});
