import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface, mapByteSigToSigStruct } from '../../../src/script/governance-admin-interface';
import {
  BOsBallot,
  BridgeOperatorsBallotTypes,
  getProposalHash,
  TargetOption,
  VoteStatus,
  VoteType,
} from '../../../src/script/proposal';
import {
  BridgeReward,
  BridgeReward__factory,
  BridgeSlash,
  BridgeSlash__factory,
  IBridge,
  MainchainBridgeManager,
  MainchainBridgeManager__factory,
  RoninBridgeManager,
  RoninBridgeManager__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../../src/types';
import { MockBridge__factory } from '../../../src/types/factories/MockBridge__factory';
import { ProposalDetailStruct, SignatureStruct } from '../../../src/types/RoninGovernanceAdmin';
import { DEFAULT_ADDRESS, ZERO_BYTES32 } from '../../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { initTest } from '../helpers/fixture';
import { getLastBlockTimestamp, compareAddrs, ContractType, mineDummyBlock } from '../helpers/utils';
import { BridgeManagerInterface } from '../../../src/script/bridge-admin-interface';
import { OperatorTuple, createManyOperatorTuples } from '../helpers/address-set-types/operator-tuple-type';
import { GlobalProposalDetailStruct } from '../../../src/types/GlobalCoreGovernance';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';

let deployer: SignerWithAddress;
let relayer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let operatorTuples: OperatorTuple[];
let beforeRelayedOperatorTuples: OperatorTuple[];
let afterRelayedOperatorTuples: OperatorTuple[];

let bridgeContract: IBridge;
let stakingContract: Staking;
let roninBridgeManager: RoninBridgeManager;
let mainchainBridgeManager: MainchainBridgeManager;
let bridgeManagerInterface: BridgeManagerInterface;

let bridgeRewardContract: BridgeReward;
let bridgeSlashContract: BridgeSlash;

let proposal: GlobalProposalDetailStruct;
let supports: VoteType[];
let signatures: SignatureStruct[] = [];

let proposalExpiryDuration = 60;
let numerator = 7;
let denominator = 10;
let snapshotId: string;

const operatorNum = 6;
const bridgeAdminNumerator = 2;
const bridgeAdminDenominator = 4;

describe('Bridge Manager test', async () => {
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

    operatorTuples = createManyOperatorTuples(signers.splice(0, operatorNum * 2));
    beforeRelayedOperatorTuples = [operatorTuples[0]];
    afterRelayedOperatorTuples = beforeRelayedOperatorTuples;

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      validatorContractAddress,
      bridgeTrackingAddress,
      roninBridgeManagerAddress,
      mainchainBridgeManagerAddress,
      bridgeSlashAddress,
      bridgeRewardAddress,
    } = await initTest('BridgeManager')({
      bridgeContract: bridgeContract.address,
      bridgeManagerArguments: {
        numerator: bridgeAdminNumerator,
        denominator: bridgeAdminDenominator,
        members: beforeRelayedOperatorTuples.map((_) => {
          return {
            operator: _.operator.address,
            governor: _.governor.address,
            weight: 100,
          };
        }),
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    bridgeSlashContract = BridgeSlash__factory.connect(bridgeSlashAddress, deployer);
    bridgeRewardContract = BridgeReward__factory.connect(bridgeRewardAddress, deployer);
    roninBridgeManager = RoninBridgeManager__factory.connect(roninBridgeManagerAddress, deployer);
    mainchainBridgeManager = MainchainBridgeManager__factory.connect(mainchainBridgeManagerAddress, deployer);
    bridgeManagerInterface = new BridgeManagerInterface(
      roninBridgeManager,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    // Mine a dummy block to reduce the first block after test setup gone too far, that exceeds proposal duration
    await mineDummyBlock();
  });

  describe('Config test', async () => {
    describe('Ronin manager', async () => {
      it('Should the Ronin bridge manager set config correctly', async () => {
        expect(await roninBridgeManager.getContract(ContractType.BRIDGE)).eq(bridgeContract.address);
        expect(await roninBridgeManager.getBridgeOperators()).deep.equal(
          beforeRelayedOperatorTuples.map((_) => _.operator.address)
        );
      });
      it('Should the Ronin bridge manager config the targets correctly', async () => {
        expect(
          await roninBridgeManager.resolveTargets([
            TargetOption.BridgeManager,
            TargetOption.GatewayContract,
            TargetOption.BridgeSlash,
            TargetOption.BridgeReward,
          ])
        ).deep.equal([
          roninBridgeManager.address,
          bridgeContract.address,
          bridgeSlashContract.address,
          bridgeRewardContract.address,
        ]);
      });
    });

    describe('Mainchain manager', async () => {
      it('Should the mainchain bridge manager set config correctly', async () => {
        expect(await mainchainBridgeManager.getContract(ContractType.BRIDGE)).eq(bridgeContract.address);
        expect(await mainchainBridgeManager.getBridgeOperators()).deep.equal(
          afterRelayedOperatorTuples.map((_) => _.operator.address)
        );
      });
      it('Should the mainchain bridge manager config the targets correctly', async () => {
        expect(
          await mainchainBridgeManager.resolveTargets([
            TargetOption.BridgeManager,
            TargetOption.GatewayContract,
            TargetOption.BridgeSlash,
            TargetOption.BridgeReward,
          ])
        ).deep.equal([mainchainBridgeManager.address, bridgeContract.address, DEFAULT_ADDRESS, DEFAULT_ADDRESS]);
      });
    });
  });

  describe('Bridge Operator Set Voting', () => {
    let expiryTimestamp: number;

    it('Should be able to vote bridge operators', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      const addingOperatorTuples = operatorTuples.slice(1, 3);
      proposal = await bridgeManagerInterface.createGlobalProposal(
        latestTimestamp + proposalExpiryDuration,
        TargetOption.BridgeManager,
        0,
        roninBridgeManager.interface.encodeFunctionData('addBridgeOperators', [
          addingOperatorTuples.map((_) => 100),
          addingOperatorTuples.map((_) => _.governor.address),
          addingOperatorTuples.map((_) => _.operator.address),
        ]),
        500_000
      );
      signatures = await bridgeManagerInterface.generateSignaturesGlobal(
        proposal,
        beforeRelayedOperatorTuples.map((_) => _.governor)
      );
      supports = signatures.map(() => VoteType.For);
      afterRelayedOperatorTuples = [...beforeRelayedOperatorTuples, ...addingOperatorTuples];

      let tx = await roninBridgeManager
        .connect(operatorTuples[0].governor)
        .proposeGlobalProposalStructAndCastVotes(proposal, supports, signatures);
      await expect(tx)
        .emit(roninBridgeManager, 'ProposalVoted')
        .withArgs(anyValue, operatorTuples[0].governor.address, VoteType.For, 100);
      expect(await roninBridgeManager.globalProposalVoted(proposal.nonce, operatorTuples[0].governor.address)).to.true;
      expect(await roninBridgeManager.getBridgeOperators()).deep.equal(
        afterRelayedOperatorTuples.map((_) => _.operator.address)
      );
    });

    it('Should be able relay the vote of bridge operators', async () => {
      expect(await mainchainBridgeManager.globalProposalRelayed(proposal.nonce)).to.false;
      expect(await mainchainBridgeManager.getBridgeOperators()).deep.equal(
        beforeRelayedOperatorTuples.map((_) => _.operator.address)
      );
      await mainchainBridgeManager
        .connect(operatorTuples[0].governor)
        .relayGlobalProposal(proposal, supports, signatures);
      expect(await mainchainBridgeManager.globalProposalRelayed(proposal.nonce)).to.true;
      expect(await mainchainBridgeManager.getBridgeOperators()).deep.equal(
        afterRelayedOperatorTuples.map((_) => _.operator.address)
      );

      beforeRelayedOperatorTuples = afterRelayedOperatorTuples;
    });

    it('Should not able to relay again', async () => {
      await expect(
        mainchainBridgeManager.connect(operatorTuples[0].governor).relayGlobalProposal(proposal, supports, signatures)
      ).revertedWithCustomError(mainchainBridgeManager, 'ErrInvalidProposalNonce');
    });

    it('Should be able to vote for a larger number of bridge operators', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      expiryTimestamp = latestTimestamp + proposalExpiryDuration;

      const addingOperatorTuples = operatorTuples.slice(3, operatorTuples.length);
      proposal = await bridgeManagerInterface.createGlobalProposal(
        expiryTimestamp,
        TargetOption.BridgeManager,
        0,
        roninBridgeManager.interface.encodeFunctionData('addBridgeOperators', [
          addingOperatorTuples.map((_) => 100),
          addingOperatorTuples.map((_) => _.governor.address),
          addingOperatorTuples.map((_) => _.operator.address),
        ]),
        500_000
      );
      signatures = await bridgeManagerInterface.generateSignaturesGlobal(
        proposal,
        beforeRelayedOperatorTuples.map((_) => _.governor)
      );
      supports = signatures.map(() => VoteType.For);
      afterRelayedOperatorTuples = [...beforeRelayedOperatorTuples, ...addingOperatorTuples];

      let tx = await roninBridgeManager
        .connect(operatorTuples[0].governor)
        .proposeGlobalProposalStructAndCastVotes(proposal, supports, signatures);
      await expect(tx)
        .emit(roninBridgeManager, 'ProposalVoted')
        .withArgs(anyValue, operatorTuples[0].governor.address, VoteType.For, 100);
      expect(await roninBridgeManager.globalProposalVoted(proposal.nonce, operatorTuples[0].governor.address)).to.true;
      expect(await roninBridgeManager.getBridgeOperators()).deep.equal(
        afterRelayedOperatorTuples.map((_) => _.operator.address)
      );
    });

    it('Should the approved proposal can be relayed on mainchain (even when the time of expiry is passed)', async () => {
      await network.provider.send('evm_setNextBlockTimestamp', [expiryTimestamp + 1]);

      expect(await mainchainBridgeManager.globalProposalRelayed(proposal.nonce)).to.false;
      expect(await mainchainBridgeManager.getBridgeOperators()).deep.equal(
        beforeRelayedOperatorTuples.map((_) => _.operator.address)
      );
      // signatures = await roninBridgeManager.getGlobalProposalSignatures(proposal.nonce);

      await mainchainBridgeManager
        .connect(operatorTuples[0].governor)
        .relayGlobalProposal(proposal, supports, signatures);
      expect(await mainchainBridgeManager.globalProposalRelayed(proposal.nonce)).to.true;
      expect(await mainchainBridgeManager.getBridgeOperators()).deep.equal(
        afterRelayedOperatorTuples.map((_) => _.operator.address)
      );
    });
  });
});
