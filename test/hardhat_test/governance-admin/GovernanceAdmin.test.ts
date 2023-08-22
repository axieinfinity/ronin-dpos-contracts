import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface, mapByteSigToSigStruct } from '../../../src/script/governance-admin-interface';
import {
  BOsBallot,
  BridgeOperatorsBallotTypes,
  getProposalHash,
  VoteStatus,
  VoteType,
} from '../../../src/script/proposal';
import {
  IBridge,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../../src/types';
import { MockBridge__factory } from '../../../src/types/factories/MockBridge__factory';
import { ProposalDetailStruct, SignatureStruct } from '../../../src/types/RoninGovernanceAdmin';
import { ZERO_BYTES32 } from '../../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { initTest } from '../helpers/fixture';
import { getLastBlockTimestamp, compareAddrs, mineDummyBlock } from '../helpers/utils';

let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];

let bridgeContract: IBridge;
let stakingContract: Staking;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let proposal: ProposalDetailStruct;
let supports: VoteType[];
let signatures: SignatureStruct[];
let ballot: BOsBallot;

let proposalExpiryDuration = 60; // TODO: why block timestamp is wrong???
let numerator = 7;
let denominator = 10;
let snapshotId: string;

describe('Governance Admin test', () => {
  before(async () => {
    [deployer, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 21 * 3));

    const logic = await new MockBridge__factory(deployer).deploy();
    const proxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logic.address,
      deployer.address,
      []
    );
    bridgeContract = MockBridge__factory.connect(proxy.address, deployer);

    const { roninGovernanceAdminAddress, stakingContractAddress } = await initTest('RoninGovernanceAdminTest')({
      bridgeContract: bridgeContract.address,
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),

        numerator,
        denominator,
      },
      governanceAdminArguments: {
        proposalExpiryDuration,
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );
  });

  describe('Test config', async () => {
    it('Should the GA set up the config correctly', async () => {
      (await governanceAdmin.getProposalExpiryDuration()).eq(proposalExpiryDuration);
    });
  });

  describe('General case of governance admin', async () => {
    before(async () => {
      // Mine a dummy block to reduce the first block after test setup gone too far, that exceeds proposal duration
      await mineDummyBlock();
    });

    describe('Proposals', () => {
      it('Should be able to propose to change staking config', async () => {
        const newMinValidatorStakingAmount = 555;
        const latestTimestamp = await getLastBlockTimestamp();
        proposal = await governanceAdminInterface.createProposal(
          latestTimestamp + proposalExpiryDuration,
          stakingContract.address,
          0,
          governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
            stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [
              newMinValidatorStakingAmount,
            ]),
          ]),
          500_000
        );
        signatures = await governanceAdminInterface.generateSignatures(proposal);
        supports = signatures.map(() => VoteType.For);

        expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address))
          .to.false;
        await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .proposeProposalStructAndCastVotes(proposal, supports, signatures);

        expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address))
          .to.true;
        expect(await stakingContract.minValidatorStakingAmount()).eq(newMinValidatorStakingAmount);
      });

      it('Should not be able to reuse already voted signatures or proposals', async () => {
        await expect(
          governanceAdmin
            .connect(trustedOrgs[0].governor)
            .proposeProposalStructAndCastVotes(proposal, supports, signatures)
        )
          .revertedWithCustomError(governanceAdmin, 'ErrInvalidProposalNonce')
          .withArgs(governanceAdmin.interface.getSighash('proposeProposalStructAndCastVotes'));
      });
    });
  });

  describe('Proposal expiry test', async () => {
    let previousProposal: ProposalDetailStruct;
    let previousHash: string;
    let previousSupports: VoteType[];
    let previousSignatures: SignatureStruct[];

    let previousProposal2: ProposalDetailStruct;

    it('Should not be able to propose a proposal with invalid expiry time', async () => {
      const newMinValidatorStakingAmount = 1337;
      const latestTimestamp = await getLastBlockTimestamp();
      const nextTimestamp = latestTimestamp + 1;
      await network.provider.send('evm_setNextBlockTimestamp', [nextTimestamp]);

      proposal = await governanceAdminInterface.createProposal(
        nextTimestamp + proposalExpiryDuration + 1,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000
      );
      signatures = await governanceAdminInterface.generateSignatures(proposal);
      supports = signatures.map(() => VoteType.For);

      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address)).to
        .false;
      await expect(
        governanceAdmin
          .connect(trustedOrgs[0].governor)
          .proposeProposalStructAndCastVotes(proposal, supports, signatures)
      ).revertedWithCustomError(governanceAdmin, 'ErrInvalidExpiryTimestamp');
    });

    it('Should the expired proposal cannot be voted anymore', async () => {
      const newMinValidatorStakingAmount = 1337;
      const latestTimestamp = await getLastBlockTimestamp();
      const expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000
      );
      previousProposal = proposal;
      previousProposal2 = proposal;
      previousHash = getProposalHash(proposal);

      signatures = await governanceAdminInterface.generateSignatures(proposal);
      supports = signatures.map(() => VoteType.For);

      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address)).to
        .false;

      const cutOffLength = Math.floor((supports.length * numerator) / denominator);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(
          proposal,
          supports.splice(0, cutOffLength - 1),
          signatures.splice(0, cutOffLength - 1)
        );

      await network.provider.send('evm_setNextBlockTimestamp', [expiryTimestamp + 1]);
      expect(
        await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .castProposalBySignatures(proposal, supports.splice(0, 1), signatures.splice(0, 1))
      )
        .emit(governanceAdmin, 'ProposalExpired')
        .withArgs(previousHash);
      await expect(
        governanceAdmin
          .connect(trustedOrgs[0].governor)
          .castProposalBySignatures(proposal, supports.splice(0, 1), signatures.splice(0, 1))
      ).revertedWithCustomError(governanceAdmin, 'ErrInvalidProposal');
    });

    it('Should the new proposal replace the expired proposal -- with implicit round', async () => {
      snapshotId = await network.provider.send('evm_snapshot');

      let currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).eq(ZERO_BYTES32);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      const newMinValidatorStakingAmount = 202881;
      const latestTimestamp = await getLastBlockTimestamp();
      const expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000,
        BigNumber.from(previousProposal.nonce)
      );

      previousSignatures = signatures = await governanceAdminInterface.generateSignatures(proposal);
      previousSupports = supports = signatures.map(() => VoteType.For);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(proposal, supports.splice(0, 1), signatures.splice(0, 1));

      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).not.eq(previousHash);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      await governanceAdmin.connect(trustedOrgs[0].governor).castProposalBySignatures(proposal, supports, signatures);
      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Executed);

      previousProposal = proposal;
      previousHash = getProposalHash(proposal);

      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should the new proposal replace the expired proposal -- with explicit round', async () => {
      let currentProposalVote = await governanceAdmin.vote(previousProposal2.chainId, previousProposal2.nonce);
      expect(currentProposalVote.hash).eq(ZERO_BYTES32);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      const newMinValidatorStakingAmount = 202881;
      const latestTimestamp = await getLastBlockTimestamp();
      const expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000,
        BigNumber.from(previousProposal2.nonce)
      );

      previousSignatures = signatures = await governanceAdminInterface.generateSignatures(proposal);
      previousSupports = supports = signatures.map(() => VoteType.For);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalForCurrentNetwork(
          proposal.expiryTimestamp,
          proposal.targets,
          proposal.values,
          proposal.calldatas,
          proposal.gasAmounts,
          supports[0]
        );

      currentProposalVote = await governanceAdmin.vote(previousProposal2.chainId, previousProposal2.nonce);
      expect(currentProposalVote.hash).not.eq(previousProposal2);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      supports.splice(0, 1);
      signatures.splice(0, 1);
      await governanceAdmin.connect(trustedOrgs[0].governor).castProposalBySignatures(proposal, supports, signatures);
      currentProposalVote = await governanceAdmin.vote(previousProposal2.chainId, previousProposal2.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Executed);

      previousProposal = proposal;
      previousHash = getProposalHash(proposal);
    });

    it('Should the expired proposal can be manually marked as expired', async () => {
      const newMinValidatorStakingAmount = 989283;
      const latestTimestamp = await getLastBlockTimestamp();
      const expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000
      );
      previousProposal = proposal;
      previousHash = getProposalHash(proposal);

      signatures = await governanceAdminInterface.generateSignatures(proposal);
      supports = signatures.map(() => VoteType.For);

      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address)).to
        .false;

      const cutOffLength = Math.floor((supports.length * numerator) / denominator);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(
          proposal,
          supports.splice(0, cutOffLength - 1),
          signatures.splice(0, cutOffLength - 1)
        );

      expect(
        await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .deleteExpired(previousProposal.chainId, previousProposal.nonce)
      ).not.emit(governanceAdmin, 'ProposalExpired');

      await network.provider.send('evm_setNextBlockTimestamp', [expiryTimestamp + 1]);

      let currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).eq(previousHash);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      expect(
        await governanceAdmin
          .connect(trustedOrgs[0].governor)
          .deleteExpired(previousProposal.chainId, previousProposal.nonce)
      )
        .emit(governanceAdmin, 'ProposalExpired')
        .withArgs(previousHash);

      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).eq(ZERO_BYTES32);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);
    });

    it('Should a proposal executed, then expiry time passes, and then a new proposal is created and executed', async () => {
      // Execute a proposal
      let currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).eq(ZERO_BYTES32);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      let newMinValidatorStakingAmount = 191293002;
      let latestTimestamp = await getLastBlockTimestamp();
      let expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000,
        BigNumber.from(previousProposal.nonce)
      );
      expect(proposal.nonce).eq(previousProposal.nonce);

      previousSignatures = signatures = await governanceAdminInterface.generateSignatures(proposal);
      previousSupports = supports = signatures.map(() => VoteType.For);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(proposal, supports.splice(0, 1), signatures.splice(0, 1));

      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      await governanceAdmin.connect(trustedOrgs[0].governor).castProposalBySignatures(proposal, supports, signatures);
      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Executed);

      previousProposal = proposal;
      previousHash = getProposalHash(proposal);

      // Wait to expiry time pass
      let nextBlockTimestamp = expiryTimestamp + 1;
      await network.provider.send('evm_setNextBlockTimestamp', [nextBlockTimestamp]);

      // Create a new proposal
      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.hash).eq(previousHash);
      expect(currentProposalVote.status).eq(VoteStatus.Executed);

      newMinValidatorStakingAmount = 491239;
      expiryTimestamp = nextBlockTimestamp + proposalExpiryDuration;

      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newMinValidatorStakingAmount]),
        ]),
        500_000
      );
      expect(proposal.nonce).eq(BigNumber.from(previousProposal.nonce).add(1));

      previousSignatures = signatures = await governanceAdminInterface.generateSignatures(proposal);
      previousSupports = supports = signatures.map(() => VoteType.For);
      previousProposal = proposal;
      previousHash = getProposalHash(proposal);

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalStructAndCastVotes(proposal, supports.splice(0, 1), signatures.splice(0, 1));

      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Pending);

      await governanceAdmin.connect(trustedOrgs[0].governor).castProposalBySignatures(proposal, supports, signatures);
      currentProposalVote = await governanceAdmin.vote(previousProposal.chainId, previousProposal.nonce);
      expect(currentProposalVote.status).eq(VoteStatus.Executed);
    });
  });

  describe('Current Network Proposal Voting', () => {
    let newConfig: BigNumberish;
    let votedSignatures: SignatureStruct[] = [];

    before(() => {
      newConfig = Math.floor(Math.random() * 1000000) + 100000;
    });

    it('Should be able to create a proposal using governor account', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      const expiryTimestamp = latestTimestamp + proposalExpiryDuration;
      proposal = await governanceAdminInterface.createProposal(
        expiryTimestamp,
        stakingContract.address,
        0,
        governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
          stakingContract.interface.encodeFunctionData('setMinValidatorStakingAmount', [newConfig]),
        ]),
        500_000
      );

      await governanceAdmin
        .connect(trustedOrgs[0].governor)
        .proposeProposalForCurrentNetwork(
          proposal.expiryTimestamp,
          proposal.targets,
          proposal.values,
          proposal.calldatas,
          proposal.gasAmounts,
          VoteType.Against
        );
      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[0].governor.address)).to
        .true;
    });

    it('Should not be able to cast vote with invalid chain id', async () => {
      await expect(
        governanceAdmin
          .connect(trustedOrgs[1].governor)
          .castProposalVoteForCurrentNetwork(
            { ...proposal, chainId: BigNumber.from(proposal.chainId).add(1) },
            VoteType.Against
          )
      ).revertedWithCustomError(governanceAdmin, 'ErrInvalidChainId');
    });

    it('Should not be able to cast vote with invalid data', async () => {
      await expect(
        governanceAdmin
          .connect(trustedOrgs[1].governor)
          .castProposalVoteForCurrentNetwork(
            { ...proposal, values: proposal.values.map((v) => BigNumber.from(v).add(1)) },
            VoteType.Against
          )
      ).revertedWithCustomError(governanceAdmin, 'ErrInvalidProposal');
    });

    it('Should be able to cast valid vote', async () => {
      await governanceAdmin.connect(trustedOrgs[1].governor).castProposalVoteForCurrentNetwork(proposal, VoteType.For);
      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[1].governor.address)).to
        .true;
    });

    it('Should not be able to cast vote again with signatures', async () => {
      const votedSignatures = await governanceAdminInterface.generateSignatures(
        proposal,
        [trustedOrgs[0].governor],
        VoteType.Against
      );
      await expect(
        governanceAdmin
          .connect(trustedOrgs[0].governor)
          .castProposalBySignatures(proposal, [VoteType.Against], votedSignatures)
      )
        .revertedWithCustomError(governanceAdmin, 'ErrAlreadyVoted')
        .withArgs(trustedOrgs[0].governor.address);
    });

    it('Should be able to cast vote using signatures', async () => {
      votedSignatures = await governanceAdminInterface.generateSignatures(
        proposal,
        [trustedOrgs[2].governor],
        VoteType.Against
      );
      await governanceAdmin
        .connect(trustedOrgs[2].governor)
        .castProposalBySignatures(proposal, [VoteType.Against], votedSignatures);
      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[2].governor.address)).to
        .true;
    });

    it('Should not be able to cast vote again without signatures', async () => {
      expect(await governanceAdmin.proposalVoted(proposal.chainId, proposal.nonce, trustedOrgs[2].governor.address)).to
        .true;
      await expect(
        governanceAdmin.connect(trustedOrgs[2].governor).castProposalVoteForCurrentNetwork(proposal, VoteType.For)
      )
        .revertedWithCustomError(governanceAdmin, 'ErrAlreadyVoted')
        .withArgs(trustedOrgs[2].governor.address);
    });

    it('Should be able to retrieve the signatures', async () => {
      const [voters, supports, signatures] = await governanceAdmin.getProposalSignatures(
        proposal.chainId,
        proposal.nonce
      );
      expect(voters).deep.equal([
        trustedOrgs[1].governor.address,
        trustedOrgs[0].governor.address,
        trustedOrgs[2].governor.address,
      ]);
      expect(supports).deep.equal([VoteType.For, VoteType.Against, VoteType.Against]);
      const emptySignatures = [0, ethers.constants.HashZero, ethers.constants.HashZero];
      expect(signatures).deep.equal([
        emptySignatures,
        emptySignatures,
        ...votedSignatures.map((sig) => [sig.v, sig.r, sig.s]),
      ]);
    });

    describe('Expired Vote', () => {
      before(async () => {
        snapshotId = await network.provider.send('evm_snapshot');
        await network.provider.send('evm_setNextBlockTimestamp', [
          BigNumber.from(proposal.expiryTimestamp).add(1).toNumber(),
        ]);
      });

      after(async () => {
        await network.provider.send('evm_revert', [snapshotId]);
      });

      it('Should be able to clear the proposal when it is expired', async () => {
        expect(
          await governanceAdmin.connect(trustedOrgs[0].governor).deleteExpired(proposal.chainId, proposal.nonce)
        ).emit(governanceAdmin, 'ProposalExpired');
        const [voters, supports, signatures] = await governanceAdmin.getProposalSignatures(
          proposal.chainId,
          proposal.nonce
        );
        expect(voters.length).eq(0);
        expect(supports.length).eq(0);
        expect(signatures.length).eq(0);
      });
    });

    describe('Approved Vote', () => {
      before(async () => {
        snapshotId = await network.provider.send('evm_snapshot');
      });

      after(async () => {
        await network.provider.send('evm_revert', [snapshotId]);
      });

      it('Should be able to cast for vote', async () => {
        for (let i = 3; i < trustedOrgs.length; i++) {
          let vote = await governanceAdmin.vote(proposal.chainId, proposal.nonce);
          if (vote.status == VoteStatus.Pending) {
            await governanceAdmin
              .connect(trustedOrgs[i].governor)
              .castProposalVoteForCurrentNetwork(proposal, VoteType.For);
          }
        }
      });

      it('Should the config change after the proposal vote is approved', async () => {
        expect(await stakingContract.minValidatorStakingAmount()).eq(newConfig);
      });
    });

    describe('Rejected Vote', () => {
      let currentConfig: BigNumberish;

      before(async () => {
        snapshotId = await network.provider.send('evm_snapshot');
        currentConfig = await stakingContract.minValidatorStakingAmount();
      });

      after(async () => {
        await network.provider.send('evm_revert', [snapshotId]);
      });

      it('Should be able to cast for vote', async () => {
        for (let i = 3; i < trustedOrgs.length; i++) {
          let vote = await governanceAdmin.vote(proposal.chainId, proposal.nonce);
          if (vote.status == VoteStatus.Pending) {
            await governanceAdmin
              .connect(trustedOrgs[i].governor)
              .castProposalVoteForCurrentNetwork(proposal, VoteType.Against);
          }
        }
      });

      it('Should the config change after the proposal vote is approved', async () => {
        const latestConfig = await stakingContract.minValidatorStakingAmount();
        expect(latestConfig).not.eq(newConfig);
        expect(latestConfig).eq(currentConfig);
      });
    });
  });
});
