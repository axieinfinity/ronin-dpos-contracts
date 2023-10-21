import { expect } from 'chai';
import { BigNumber, BigNumberish, ContractTransaction, ethers as EthersType } from 'ethers';
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
} from '../../../src/types';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { Address } from 'hardhat-deploy/dist/types';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { getEmergencyExitBallotHash } from '../../../src/script/proposal';

let roninValidatorSet: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let poolAdmin: SignerWithAddress;
let coinbase: SignerWithAddress;
let bridgeOperator: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];
let compromisedValidator: ValidatorCandidateAddressSet;

const localValidatorCandidatesLength = 5;
const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 5;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const slashDoubleSignAmount = BigNumber.from(2000);
const emergencyExitLockedAmount = BigNumber.from(500);
const waitingSecsToRevoke = 7 * 86400; // 7 days
const emergencyExpiryDuration = 14 * 86400; // 14 days

let consensusAddr: Address;
let recipientAfterUnlockedFund: Address;
let requestedAt: BigNumberish;
let expiredAt: BigNumberish;
let voteHash: string;
let snapshotId: string;
let totalStakedAmount: BigNumber;

describe('Emergency Exit test', () => {
  let tx: ContractTransaction;
  let requestBlock: EthersType.providers.Block;

  before(async () => {
    [poolAdmin, coinbase, bridgeOperator, deployer, ...signers] = await ethers.getSigners();

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 6));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, localValidatorCandidatesLength * 3));

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
      fastFinalityTrackingAddress,
    } = await initTest('EmergencyExit')({
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
        waitingSecsToRevoke,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxValidatorCandidate,
        emergencyExitLockedAmount,
        emergencyExpiryDuration,
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

    const stakedAmount = validatorCandidates.map((_, i) =>
      minValidatorStakingAmount.mul(2).add(validatorCandidates.length - i)
    );
    for (let i = 0; i < validatorCandidates.length; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          2_00,
          {
            value: stakedAmount[i],
          }
        );
    }

    await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    compromisedValidator = validatorCandidates[validatorCandidates.length - 1];
    totalStakedAmount = stakedAmount[validatorCandidates.length - 1];
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  it('Should be able to get list of the validator candidates', async () => {
    expect(validatorCandidates.map((v) => v.consensusAddr.address)).deep.equal(
      await roninValidatorSet.getBlockProducers()
    );
  });

  it('Should not be able to request emergency exit using unauthorized accounts', async () => {
    await expect(
      stakingContract.requestEmergencyExit(compromisedValidator.consensusAddr.address)
    ).revertedWithCustomError(stakingContract, 'ErrOnlyPoolAdminAllowed');
  });

  it('Should be able to request emergency exit', async () => {
    tx = await stakingContract
      .connect(compromisedValidator.poolAdmin)
      .requestEmergencyExit(compromisedValidator.consensusAddr.address);
  });

  it('Should not be able to request emergency exit again', async () => {
    await expect(
      stakingContract
        .connect(compromisedValidator.poolAdmin)
        .requestEmergencyExit(compromisedValidator.consensusAddr.address)
    ).revertedWithCustomError(roninValidatorSet, 'ErrAlreadyRequestedEmergencyExit');
  });

  it('Should the request tx emit event CandidateRevokingTimestampUpdated', async () => {
    requestBlock = await ethers.provider.getBlock(tx.blockNumber!);
    await expect(tx)
      .emit(roninValidatorSet, 'CandidateRevokingTimestampUpdated')
      .withArgs(compromisedValidator.consensusAddr.address, requestBlock.timestamp + waitingSecsToRevoke);
  });

  it('Should the request tx emit event EmergencyExitRequested', async () => {
    await expect(tx)
      .emit(roninValidatorSet, 'EmergencyExitRequested')
      .withArgs(compromisedValidator.consensusAddr.address, emergencyExitLockedAmount);
  });

  it('Should the request tx emit event EmergencyExitPollCreated', async () => {
    consensusAddr = compromisedValidator.consensusAddr.address;
    recipientAfterUnlockedFund = compromisedValidator.treasuryAddr.address;
    requestedAt = requestBlock.timestamp;
    expiredAt = requestBlock.timestamp + emergencyExpiryDuration;
    voteHash = getEmergencyExitBallotHash(consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt);

    await expect(tx)
      .emit(governanceAdmin, 'EmergencyExitPollCreated')
      .withArgs(voteHash, consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt);
  });

  it("Should the emergency exit's requester be still in the validator list", async () => {
    expect(validatorCandidates.map((v) => v.consensusAddr.address)).deep.equal(
      await roninValidatorSet.getBlockProducers()
    );
    expect(await roninValidatorSet.isBlockProducer(compromisedValidator.consensusAddr.address)).to.true;
  });

  // it("Should the exit's requester be removed in block producer and bridge operator list in next epoch", async () => {
  //   await mineBatchTxs(async () => {
  //     await roninValidatorSet.endEpoch();
  //     tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
  //   });

  //   expect(await roninValidatorSet.isValidatorCandidate(compromisedValidator.consensusAddr.address)).to.true;
  //   expect(await roninValidatorSet.isValidator(compromisedValidator.consensusAddr.address)).to.false;
  //   expect(await roninValidatorSet.isBlockProducer(compromisedValidator.consensusAddr.address)).to.false;
  //   await RoninValidatorSet.expects.emitBlockProducerSetUpdatedEvent(
  //     tx,
  //     undefined,
  //     undefined,
  //     validatorCandidates
  //       .map((v) => v.consensusAddr.address)
  //       .filter((v) => v != compromisedValidator.consensusAddr.address)
  //   );
  // });
  describe('Valid emergency exit', () => {
    let balance: BigNumberish;

    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
      balance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should the governor vote for an emergency exit', async () => {
      tx = await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .voteEmergencyExit(voteHash, consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt);
    });
    it('Should the vote tx emit event EmergencyExitPollVoted', async () => {
      await expect(tx)
        .emit(governanceAdmin, 'EmergencyExitPollVoted')
        .withArgs(voteHash, trustedOrgs[0].governor.address);
    });

    it('Should the vote tx emit event EmergencyExitPollApproved', async () => {
      await expect(tx).emit(governanceAdmin, 'EmergencyExitPollApproved').withArgs(voteHash);
    });

    it('Should the vote tx emit event EmergencyExitLockedFundReleased', async () => {
      await expect(tx)
        .emit(roninValidatorSet, 'EmergencyExitLockedFundReleased')
        .withArgs(
          compromisedValidator.consensusAddr.address,
          compromisedValidator.treasuryAddr.address,
          emergencyExitLockedAmount
        );
    });

    it('Should the requester receive the unlocked fund', async () => {
      const currentBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      expect(currentBalance.sub(balance)).eq(emergencyExitLockedAmount);
    });

    it('Should the governor still able to vote', async () => {
      tx = await governanceAdmin
        .connect(trustedOrgs[1].governor)
        .voteEmergencyExit(voteHash, consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt);
      await expect(tx).not.emit(roninValidatorSet, 'EmergencyExitLockedFundReleased');
    });

    it('Should the requester not receive the unlocked fund again', async () => {
      const currentBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      expect(currentBalance.sub(balance)).eq(emergencyExitLockedAmount);
    });

    it('Should the requester receive the total staked amount at the next period ending', async () => {
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });

      const currentBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      expect(currentBalance.sub(balance)).eq(totalStakedAmount);
    });

    it('Should the requester not receive again in the next period ending', async () => {
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });

      const currentBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      expect(currentBalance.sub(balance)).eq(totalStakedAmount);
    });
  });

  describe('Expired emergency exit', () => {
    let treasuryBalance: BigNumberish;
    let stakingVestingBalance: BigNumberish;

    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
      treasuryBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      stakingVestingBalance = await ethers.provider.getBalance(stakingVesting.address);
      await network.provider.send('evm_increaseTime', [emergencyExpiryDuration * 2]);
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should the governor not be able to vote for an expiry emergency exit', async () => {
      tx = await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .voteEmergencyExit(voteHash, consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt);
      await expect(tx).emit(governanceAdmin, 'EmergencyExitPollExpired').withArgs(voteHash);
      await expect(
        governanceAdmin
          .connect(trustedOrgs[1].governor)
          .voteEmergencyExit(voteHash, consensusAddr, recipientAfterUnlockedFund, requestedAt, expiredAt)
      ).revertedWithCustomError(governanceAdmin, 'ErrQueryForExpiredVote');
    });

    it('Should be able to recycle the locked fund and transfer back the amount left', async () => {
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const currentTreasuryBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      const currentStakingVestingBalance = await ethers.provider.getBalance(stakingVesting.address);
      expect(currentTreasuryBalance.sub(treasuryBalance)).eq(totalStakedAmount.sub(emergencyExitLockedAmount));
      expect(currentStakingVestingBalance.sub(stakingVestingBalance)).eq(emergencyExitLockedAmount);
      expect(await roninValidatorSet.isValidatorCandidate(compromisedValidator.consensusAddr.address)).to.false;
    });

    it('Should not be able to receive fund again', async () => {
      await RoninValidatorSet.EpochController.setTimestampToPeriodEnding();
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        tx = await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const currentTreasuryBalance = await ethers.provider.getBalance(compromisedValidator.treasuryAddr.address);
      const currentStakingVestingBalance = await ethers.provider.getBalance(stakingVesting.address);
      expect(currentTreasuryBalance.sub(treasuryBalance)).eq(totalStakedAmount.sub(emergencyExitLockedAmount));
      expect(currentStakingVestingBalance.sub(stakingVestingBalance)).eq(emergencyExitLockedAmount);
    });
  });
});
