import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
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
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../src/types';
import { MockBridge__factory } from '../../src/types/factories/MockBridge__factory';
import { ProposalDetailStruct, SignatureStruct } from '../../src/types/RoninGovernanceAdmin';
import { ZERO_BYTES32 } from '../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { initTest } from '../helpers/fixture';
import { getLastBlockTimestamp, compareAddrs } from '../helpers/utils';

let deployer: SignerWithAddress;
let relayer: SignerWithAddress;
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

let proposalExpiryDuration = 60;
let numerator = 7;
let denominator = 10;
let snapshotId: string;

describe('Bridge Admin test', async () => {
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
      network.config.chainId!,
      { proposalExpiryDuration },
      ...trustedOrgs.map((_) => _.governor)
    );
  });

  // TODO: move this test suite to BridgeAdmin test
  describe('Bridge Operator Set Voting', () => {
    before(async () => {
      const latestBOset = await governanceAdmin.lastSyncedBridgeOperatorSetInfo();
      expect(latestBOset.period).eq(0);
      expect(latestBOset.epoch).eq(0);
      expect(latestBOset.operators).deep.equal([]);
    });
    describe('Vote the set on Ronin chain', async () => {
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
        expect(latestBOset.operators).deep.equal(ballot.operators);
      });
      it('Should be able relay vote bridge operators', async () => {
        expect(await mainchainGovernanceAdmin.bridgeOperatorsRelayed(ballot.period, ballot.epoch)).to.false;
        const [, signatures] = await governanceAdmin.getBridgeOperatorVotingSignatures(ballot.period, ballot.epoch);
        await mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures);
        expect(await mainchainGovernanceAdmin.bridgeOperatorsRelayed(ballot.period, ballot.epoch)).to.true;
        const bridgeOperators = await bridgeContract.getBridgeOperators();
        expect([...bridgeOperators].sort(compareAddrs)).deep.equal(ballot.operators);
        const latestBOset = await mainchainGovernanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).deep.equal(ballot.operators);
      });
      it('Should not able to relay again', async () => {
        await expect(
          mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures)
        ).revertedWithCustomError(mainchainGovernanceAdmin, 'ErrQueryForOutdatedBridgeOperatorSet');
      });
      it('Should not be able to relay using invalid period/epoch', async () => {
        await expect(
          mainchainGovernanceAdmin
            .connect(relayer)
            .relayBridgeOperators(
              { ...ballot, period: BigNumber.from(ballot.period).add(1), operators: [ethers.constants.AddressZero] },
              signatures
            )
        ).revertedWithCustomError(mainchainGovernanceAdmin, 'ErrQueryForOutdatedBridgeOperatorSet');
      });
      it('Should not be able to use the signatures for another period', async () => {
        const ballot = {
          period: 100,
          epoch: 10_000,
          operators: trustedOrgs.slice(0, 1).map((v) => v.bridgeVoter.address),
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWithCustomError(
          governanceAdmin,
          'ErrInvalidSignerOrder'
        );
      });
      it('Should not be able to vote for duplicated operators', async () => {
        const ballot = {
          period: 100,
          epoch: 10_000,
          operators: [ethers.constants.AddressZero, ethers.constants.AddressZero],
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWithCustomError(
          governanceAdmin,
          'ErrInvalidOrderOfBridgeOperator'
        );
      });
      it('Should be able to vote for the same operator set again', async () => {
        ballot = {
          ...ballot,
          epoch: BigNumber.from(ballot.epoch).add(1),
        };
        signatures = await Promise.all(
          trustedOrgs.map((g) =>
            g.bridgeVoter
              ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
              .then(mapByteSigToSigStruct)
          )
        );
        await governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures);
      });
      it('Should not be able to relay with the same operator set', async () => {
        await expect(
          mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures)
        ).revertedWithCustomError(mainchainGovernanceAdmin, 'ErrBridgeOperatorSetIsAlreadyVoted');
      });
      it('Should not be able to vote bridge operators with a smaller epoch/period', async () => {
        ballot = {
          period: 100,
          epoch: 100,
          operators: trustedOrgs.map((v) => v.bridgeVoter.address),
        };
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWithCustomError(
          governanceAdmin,
          'ErrQueryForOutdatedBridgeOperatorSet'
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
        await expect(governanceAdmin.voteBridgeOperatorsBySignatures(ballot, signatures)).revertedWithCustomError(
          governanceAdmin,
          'ErrInvalidOrderOfBridgeOperator'
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
        expect(latestBOset.operators).deep.equal(ballot.operators);
      });
      it('Should be able relay vote bridge operators', async () => {
        const [, signatures] = await governanceAdmin.getBridgeOperatorVotingSignatures(ballot.period, ballot.epoch);
        await mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot, signatures);
        const bridgeOperators = await bridgeContract.getBridgeOperators();
        expect([...bridgeOperators].sort(compareAddrs)).deep.equal(ballot.operators);
        const latestBOset = await mainchainGovernanceAdmin.lastSyncedBridgeOperatorSetInfo();
        expect(latestBOset.period).eq(ballot.period);
        expect(latestBOset.epoch).eq(ballot.epoch);
        expect(latestBOset.operators).deep.equal(ballot.operators);
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
        expect(latestBOset.operators).deep.equal(ballot.operators);
      });
    });

    describe('Relay the set on Mainchain', async () => {
      it('Should be able to relay to mainchain governance admin contract', async () => {
        expect(await mainchainGovernanceAdmin.proposalRelayed(proposal.chainId, proposal.nonce)).to.false;
        await mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures);
        expect(await mainchainGovernanceAdmin.proposalRelayed(proposal.chainId, proposal.nonce)).to.true;
      });

      it('Should not be able to relay again', async () => {
        await expect(mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures))
          .revertedWithCustomError(mainchainGovernanceAdmin, 'ErrInvalidProposalNonce')
          .withArgs(mainchainGovernanceAdmin.interface.getSighash('relayProposal'));
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
    });
  });
});
