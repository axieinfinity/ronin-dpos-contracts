import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import { GovernanceAdminInterface, mapByteSigToSigStruct } from '../../src/script/governance-admin-interface';
import { BOsBallot, BridgeOperatorsBallotTypes, VoteType } from '../../src/script/proposal';
import {
  IBridge,
  MainchainGovernanceAdmin,
  MainchainGovernanceAdmin__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
} from '../../src/types';
import { MockBridge__factory } from '../../src/types/factories/MockBridge__factory';
import { ProposalDetailStruct } from '../../src/types/GovernanceAdmin';
import { SignatureStruct } from '../../src/types/RoninGovernanceAdmin';
import { initTest } from '../helpers/fixture';

let deployer: SignerWithAddress;
let relayer: SignerWithAddress;
let governors: SignerWithAddress[];

let bridgeContract: IBridge;
let stakingContract: Staking;
let mainchainGovernanceAdmin: MainchainGovernanceAdmin;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let proposal: ProposalDetailStruct;
let supports: VoteType[];
let signatures: SignatureStruct[];
let ballot: BOsBallot;

describe('Governance Admin test', () => {
  before(async () => {
    [deployer, relayer, ...governors] = await ethers.getSigners();
    governors = governors.slice(0, 10);
    governors = governors.sort((v1, v2) => v1.address.toLowerCase().localeCompare(v2.address.toLowerCase()));

    bridgeContract = await new MockBridge__factory(deployer).deploy();

    const { roninGovernanceAdminAddress, mainchainGovernanceAdminAddress, stakingContractAddress } = await initTest(
      'RoninGovernanceAdmin.test'
    )({
      bridgeContract: bridgeContract.address,
      roninTrustedOrganizationArguments: {
        trustedOrganizations: governors.map((v) => ({
          consensusAddr: v.address,
          governor: v.address,
          bridgeVoter: v.address,
          weight: 100,
          addedBlock: 0,
        })),

        numerator: 1,
        denominator: 2,
      },
      mainchainGovernanceAdminArguments: {
        relayers: [relayer.address],
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, ...governors);
    mainchainGovernanceAdmin = MainchainGovernanceAdmin__factory.connect(mainchainGovernanceAdminAddress, deployer);
  });

  it('Should be able to propose to change staking config', async () => {
    proposal = await governanceAdminInterface.createProposal(
      stakingContract.address,
      0,
      governanceAdminInterface.interface.encodeFunctionData('functionDelegateCall', [
        stakingContract.interface.encodeFunctionData('setMinValidatorBalance', [555]),
      ]),
      500_000
    );
    signatures = await governanceAdminInterface.generateSignatures(proposal);
    supports = signatures.map(() => VoteType.For);

    await governanceAdmin.connect(governors[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
    expect(await stakingContract.minValidatorBalance()).eq(555);
  });

  it('Should not be able to reuse already voted signatures or proposals', async () => {
    await expect(
      governanceAdmin.connect(governors[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures)
    ).revertedWith('CoreGovernance: invalid proposal nonce');
  });

  it('Should be able to relay to mainchain governance admin contract', async () => {
    await mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures);
  });

  it('Should not be able to relay again', async () => {
    await expect(mainchainGovernanceAdmin.connect(relayer).relayProposal(proposal, supports, signatures)).revertedWith(
      'CoreGovernance: invalid proposal nonce'
    );
  });

  it('Should be able to vote bridge operators', async () => {
    ballot = {
      period: 10,
      operators: governors.map((v) => v.address),
    };
    signatures = await Promise.all(
      governors.map((g) =>
        g
          ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
          .then(mapByteSigToSigStruct)
      )
    );
    await governanceAdmin.voteBridgeOperatorsBySignatures(ballot.period, ballot.operators, signatures);
  });

  it('Should be able relay vote bridge operators', async () => {
    await mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot.period, ballot.operators, signatures);
    expect(await bridgeContract.getBridgeOperators()).eql(governors.map((v) => v.address));
  });

  it('Should not able to relay again', async () => {
    await expect(
      mainchainGovernanceAdmin.connect(relayer).relayBridgeOperators(ballot.period, ballot.operators, signatures)
    ).revertedWith('BOsGovernanceRelay: query for outdated period');
  });

  it('Should not be able to use the signatures for another period', async () => {
    ballot = {
      period: 100,
      operators: governors.map((v) => v.address),
    };
    await expect(
      governanceAdmin.voteBridgeOperatorsBySignatures(ballot.period, ballot.operators, signatures)
    ).revertedWith('BOsGovernanceProposal: invalid order');
  });

  it('Should not be able to vote bridge operators with a smaller period', async () => {
    ballot = {
      period: 5,
      operators: governors.map((v) => v.address),
    };
    signatures = await Promise.all(
      governors.map((g) =>
        g
          ._signTypedData(governanceAdminInterface.domain, BridgeOperatorsBallotTypes, ballot)
          .then(mapByteSigToSigStruct)
      )
    );
    await expect(
      governanceAdmin.voteBridgeOperatorsBySignatures(ballot.period, ballot.operators, signatures)
    ).revertedWith('BOsGovernanceProposal: query for outdated period');
  });
});
