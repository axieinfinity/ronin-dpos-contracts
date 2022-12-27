import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface, mapByteSigToSigStruct } from '../../src/script/governance-admin-interface';
import {
  BOsBallot,
  BridgeOperatorsBallotTypes,
  getProposalHash,
  VoteStatus,
  VoteType,
} from '../../src/script/proposal';
import {
  IBridge,
  MainchainGovernanceAdmin,
  MainchainGovernanceAdmin__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../src/types';
import { MockBridge__factory } from '../../src/types/factories/MockBridge__factory';
import { ProposalDetailStruct } from '../../src/types/GovernanceAdmin';
import { SignatureStruct } from '../../src/types/RoninGovernanceAdmin';
import { randomAddress, ZERO_BYTES32 } from '../../src/utils';
import { createManyTrustedOrganizationAddressSets, TrustedOrganizationAddressSet } from '../helpers/address-set-types';
import { initTest } from '../helpers/fixture';
import { getLastBlockTimestamp, compareAddrs } from '../helpers/utils';

let deployer: SignerWithAddress;
let relayer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];

let bridgeContract: IBridge;
let stakingContract: Staking;
let mainchainGovernanceAdmin: MainchainGovernanceAdmin;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let proposal: ProposalDetailStruct;
let supports: VoteType[];
let signatures: SignatureStruct[];
let ballot: BOsBallot;

let proposalExpiryDuration = 60;
let numerator = 7;
let denominator = 10;

describe('Governance Admin test', () => {
  before(async () => {
    [deployer, relayer, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 21 * 3));

    const logic = await new MockBridge__factory(deployer).deploy();
    const proxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logic.address,
      deployer.address,
      []
    );
    bridgeContract = MockBridge__factory.connect(proxy.address, deployer);

    const { roninGovernanceAdminAddress, mainchainGovernanceAdminAddress, stakingContractAddress } = await initTest(
      'RoninGovernanceAdminTest'
    )({
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
      mainchainGovernanceAdminArguments: {
        relayers: [relayer.address],
      },
      governanceAdminArguments: {
        proposalExpiryDuration,
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );
    mainchainGovernanceAdmin = MainchainGovernanceAdmin__factory.connect(mainchainGovernanceAdminAddress, deployer);
    await TransparentUpgradeableProxyV2__factory.connect(proxy.address, deployer).changeAdmin(
      mainchainGovernanceAdmin.address
    );
  });

  describe('General case of governance admin', async () => {
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
        ).revertedWith('CoreGovernance: invalid proposal nonce');
      });

      it('Should be able to relay to mainchain governance admin contract', async () => {
        expect(await mainchainGovernanceAdmin.proposalRelayed(proposal.chainId, proposal.nonce)).to.false;
        await mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures);
        expect(await mainchainGovernanceAdmin.proposalRelayed(proposal.chainId, proposal.nonce)).to.true;
      });

      it('Should not be able to relay again', async () => {
        await expect(
          mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures)
        ).revertedWith('CoreGovernance: invalid proposal nonce');
      });
    });

    describe('Bridge Operator Set Voting', () => {
      before(async () => {
        const latestBOset = await governanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(0);
        expect(latestBOset.epoch).eq(0);
        expect(latestBOset.operators).eql([]);
      });

      it('Should be able to vote bridge operators', async () => {
        ballot = {
          period: 10,
          epoch: 10_000,
          operators: trustedOrgs
            .slice(0, 2)
            .map((v) => v.bridgeVoter.address)
            .sort(compareAddrs),
        };
        signatures = await Promise.all(
          trustedOrgs.map((g) =>
            g.bridgeVoter
              ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
              .then(mapByteSigToSigStruct)
          )
        );
        expect(
          await governanceAdmin.bridgeOperatorsVoted(ballot.period, ballot.epoch, trustedOrgs[0].bridgeVoter.address)
        ).to.false;
        await governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures);
        expect(
          await governanceAdmin.bridgeOperatorsVoted(ballot.period, ballot.epoch, trustedOrgs[0].bridgeVoter.address)
        ).to.true;

        const latestBOset = await governanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).eql(ballot.operators);
      });

      it('Should be able relay vote bridge operators', async () => {
        expect(await mainchainGovernanceAdmin.bridgeOperatorsRelayed(ballot.period, ballot.epoch)).to.false;
        await mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures);
        expect(await mainchainGovernanceAdmin.bridgeOperatorsRelayed(ballot.period, ballot.epoch)).to.true;
        const bridgeOperators = await bridgeContract.getBridgeOperators();
        expect([...bridgeOperators].sort(compareAddrs)).eql(ballot.operators);
        const latestBOset = await mainchainGovernanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).eql(ballot.operators);
      });

      it('Should not able to relay again', async () => {
        await expect(mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures)).revertedWith(
          'BOsGovernanceRelay: query for outdated bridge operator set'
        );
      });

      it('Should not be able to relay using invalid period/epoch', async () => {
        await expect(
          mainchainGovernanceAdmin
            .connect(relayer)
            .relayBridgeOperators(
              { ...ballot, period: BigNumber.from(ballot.period).add(1), operators: [ethers.constants.AddressZero] },
              signatures
            )
        ).revertedWith('BOsGovernanceRelay: query for outdated bridge operator set');
      });

      it('Should not be able to use the signatures for another period', async () => {
        const ballot = {
          period: 100,
          epoch: 10_000,
          operators: trustedOrgs.slice(0, 1).map((v) => v.bridgeVoter.address),
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWith(
          'BOsGovernanceProposal: invalid signer order'
        );
      });

      it('Should not be able to vote for duplicated operators', async () => {
        const ballot = {
          period: 100,
          epoch: 10_000,
          operators: [ethers.constants.AddressZero, ethers.constants.AddressZero],
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWith(
          'BridgeOperatorsBallot: invalid order of bridge operators'
        );
      });

      it('Should not be able to vote for the same operator set again', async () => {
        ballot = {
          ...ballot,
          epoch: BigNumber.from(ballot.epoch).add(1),
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWith(
          'BridgeOperatorsBallot: bridge operator set is already voted'
        );
      });

      it('Should not be able to vote bridge operators with a smaller epoch/period', async () => {
        ballot = {
          period: 100,
          epoch: 100,
          operators: trustedOrgs.map((v) => v.bridgeVoter.address),
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWith(
          'BOsGovernanceProposal: query for outdated bridge operator set'
        );
      });

      it('Should not be able to vote invalid order of bridge operators', async () => {
        const duplicatedNumber = 11;
        ballot = {
          period: 100,
          epoch: 10_001,
          operators: [
            ...trustedOrgs.map((v, i) => (i < duplicatedNumber ? v.bridgeVoter.address : randomAddress())),
            ethers.constants.AddressZero,
          ],
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWith(
          'BridgeOperatorsBallot: invalid order of bridge operators'
        );
      });

      it('Should be able to vote for a larger number of bridge operators', async () => {
        ballot.operators.pop();
        ballot = {
          ...ballot,
          operators: [ethers.constants.AddressZero, ...ballot.operators.sort(compareAddrs)],
        };
        signatures = await Promise.all(
          trustedOrgs.map((g) =>
            g.bridgeVoter
              ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
              .then(mapByteSigToSigStruct)
          )
        );
        const lastLength = (await governanceAdmin.lastSyncedBridgeOperatorSetInfo()).operators.length;
        await governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures);
        const latestBOset = await governanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(lastLength).not.eq(ballot.operators.length);
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).eql(ballot.operators);
      });

      it('Should be able relay vote bridge operators', async () => {
        await mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures);
        const bridgeOperators = await bridgeContract.getBridgeOperators();
        expect([...bridgeOperators].sort(compareAddrs)).eql(ballot.operators);
        const latestBOset = await mainchainGovernanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).eql(ballot.operators);
      });

      it('Should be able to vote for a same number of bridge operators', async () => {
        ballot.operators.pop();
        ballot = {
          ...ballot,
          epoch: BigNumber.from(ballot.epoch).add(1),
          operators: [...ballot.operators, randomAddress()].sort(compareAddrs),
        };
        signatures = await Promise.all(
          trustedOrgs.map((g) =>
            g.bridgeVoter
              ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
              .then(mapByteSigToSigStruct)
          )
        );
        const lastLength = (await governanceAdmin.lastSyncedBridgeOperatorSetInfo()).operators.length;
        await governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures);
        const latestBOset = await governanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(lastLength).eq(ballot.operators.length);
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).eql(ballot.operators);
      });
    });
  });

  describe('Proposal expiry test', async () => {
    let previousProposal: ProposalDetailStruct;
    let previousHash: string;
    let previousSupports: VoteType[];
    let previousSignatures: SignatureStruct[];

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
      ).revertedWith('Proposal: invalid expiry timestamp');
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
      ).revertedWith('GovernanceAdmin: cast vote for invalid proposal');
    });

    it('Should the new proposal replace the expired proposal', async () => {
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
    });

    it('Should the approved proposal can be relayed on mainchain (even when the time of expiry is passed)', async () => {
      expect(
        await mainchainGovernanceAdmin
          .connect(relayer)
          .relayProposal(previousProposal, previousSupports, previousSignatures)
      )
        .emit(mainchainGovernanceAdmin, 'ProposalApproved')
        .withArgs(previousHash);
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
});
