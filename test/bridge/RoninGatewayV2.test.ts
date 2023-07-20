import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';
import { getReceiptHash } from '../../src/script/bridge';

import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import { VoteStatus } from '../../src/script/proposal';
import {
  BridgeTracking,
  BridgeTracking__factory,
  ERC20PresetMinterPauser__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  MockRoninGatewayV2Extended,
  MockRoninGatewayV2Extended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../src/types';
import { ERC20PresetMinterPauser } from '../../src/types/ERC20PresetMinterPauser';
import { ReceiptStruct } from '../../src/types/IRoninGatewayV2';
import { DEFAULT_ADDRESS } from '../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';
import { initTest } from '../helpers/fixture';
import { getRole, mineBatchTxs } from '../helpers/utils';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: ValidatorCandidateAddressSet[];
let signers: SignerWithAddress[];

let bridgeContract: MockRoninGatewayV2Extended;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;
let token: ERC20PresetMinterPauser;

let period: BigNumberish;
let receipts: ReceiptStruct[];

const maxValidatorNumber = 6;
const maxPrioritizedValidatorNumber = maxValidatorNumber - 2;
const minValidatorStakingAmount = 500;

// only requires 3 operator for the proposal to pass
const numerator = 3;
const denominator = maxValidatorNumber;

// requires 1 trusted operators for the proposal to pass
const trustedNumerator = 1;
const trustedDenominator = maxPrioritizedValidatorNumber;

const mainchainId = 1;
const numberOfBlocksInEpoch = 600;

describe('Ronin Gateway V2 test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    // Set up that all candidates except the 2 last ones are trusted org
    candidates = createManyValidatorCandidateAddressSets(signers.splice(0, maxValidatorNumber * 3));
    trustedOrgs = createManyTrustedOrganizationAddressSets(
      candidates.slice(0, maxPrioritizedValidatorNumber).map((_) => _.consensusAddr),
      signers.splice(0, maxPrioritizedValidatorNumber),
      signers.splice(0, maxPrioritizedValidatorNumber)
    );

    // Deploys bridge contracts
    token = await new ERC20PresetMinterPauser__factory(deployer).deploy('ERC20', 'ERC20');
    const logic = await new MockRoninGatewayV2Extended__factory(deployer).deploy();
    const proxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logic.address,
      deployer.address,
      logic.interface.encodeFunctionData('initialize', [
        ethers.constants.AddressZero,
        numerator,
        denominator,
        trustedNumerator,
        trustedDenominator,
        [],
        [[token.address], [token.address]],
        [[mainchainId], [0]],
        [0],
      ])
    );
    bridgeContract = MockRoninGatewayV2Extended__factory.connect(proxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      validatorContractAddress,
      bridgeTrackingAddress,
      roninTrustedOrganizationAddress,
      profileAddress,
    } = await initTest('RoninGatewayV2')({
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
      stakingArguments: {
        minValidatorStakingAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch,
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    bridgeTracking = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);
    await governanceAdminInterface.functionDelegateCalls(
      [stakingContract.address, roninValidatorSet.address],
      [
        stakingContract.interface.encodeFunctionData('initializeV3', [profileAddress]),
        roninValidatorSet.interface.encodeFunctionData('initializeV3', [profileAddress]),
      ]
    );
    await roninValidatorSet.initEpoch();

    await TransparentUpgradeableProxyV2__factory.connect(proxy.address, deployer).changeAdmin(governanceAdmin.address);
    await governanceAdminInterface.functionDelegateCalls(
      Array.from(Array(3).keys()).map(() => bridgeContract.address),
      [
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRole('BRIDGE_TRACKING_CONTRACT'),
          bridgeTracking.address,
        ]),
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRole('VALIDATOR_CONTRACT'),
          roninValidatorSet.address,
        ]),
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRole('RONIN_TRUSTED_ORGANIZATION_CONTRACT'),
          roninTrustedOrganizationAddress,
        ]),
      ]
    );

    // Applies candidates and double check the bridge operators
    for (let i = 0; i < candidates.length; i++) {
      await stakingContract
        .connect(candidates[i].poolAdmin)
        .applyValidatorCandidate(
          candidates[i].candidateAdmin.address,
          candidates[i].consensusAddr.address,
          candidates[i].treasuryAddr.address,
          1,
          { value: minValidatorStakingAmount + candidates.length - i }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    period = await roninValidatorSet.currentPeriod();

    // TODO: uncomment below logic

    // expect((await roninValidatorSet.getBridgeOperators())._bridgeOperatorList).deep.equal(
    //   candidates.map((v) => v.bridgeOperator.address)
    // );
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  describe('Voting Test', () => {
    let snapshotId: any;
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
      await governanceAdminInterface.functionDelegateCalls(
        Array.from(Array(1).keys()).map(() => bridgeContract.address),
        [bridgeContract.interface.encodeFunctionData('setTrustedThreshold', [0, 1])]
      );
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    // TODO: uncomment below logic

    // it('Should be able to bulk deposits using bridge operator accounts', async () => {
    //   receipts = [
    //     {
    //       id: 0,
    //       kind: 0,
    //       mainchain: {
    //         addr: deployer.address,
    //         tokenAddr: token.address,
    //         chainId: mainchainId,
    //       },
    //       ronin: {
    //         addr: deployer.address,
    //         tokenAddr: token.address,
    //         chainId: network.config.chainId!,
    //       },
    //       info: { erc: 0, id: 0, quantity: 100 },
    //     },
    //   ];
    //   receipts.push({ ...receipts[0], id: 1 });

    //   for (let i = 0; i < numerator - 1; i++) {
    //     const tx = await bridgeContract.connect(candidates[i].bridgeOperator).tryBulkDepositFor(receipts);
    //     await expect(tx).not.emit(bridgeContract, 'Deposited');
    //   }

    //   for (let i = 0; i < receipts.length; i++) {
    //     const vote = await bridgeContract.depositVote(receipts[i].mainchain.chainId, receipts[i].id);
    //     expect(vote.status).eq(VoteStatus.Pending);
    //     const [totalWeight, trustedWeight] = await bridgeContract.getDepositVoteWeight(
    //       mainchainId,
    //       i,
    //       getReceiptHash(receipts[i])
    //     );
    //     expect(totalWeight).eq(numerator - 1);
    //     expect(trustedWeight).eq(numerator - 1);
    //   }
    // });

    // it('Should be able to update the vote weights when a bridge operator exited', async () => {
    //   await stakingContract.connect(candidates[0].poolAdmin).requestEmergencyExit(candidates[0].consensusAddr.address);
    //   await mineBatchTxs(async () => {
    //     await roninValidatorSet.endEpoch();
    //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    //   });
    //   {
    //     const [totalWeight, trustedWeight] = await bridgeContract.getDepositVoteWeight(
    //       mainchainId,
    //       0,
    //       getReceiptHash(receipts[0])
    //     );
    //     expect(totalWeight).eq(1);
    //     expect(trustedWeight).eq(1);
    //   }
    //   {
    //     const [totalWeight, trustedWeight] = await bridgeContract.getDepositVoteWeight(
    //       mainchainId,
    //       1,
    //       getReceiptHash(receipts[1])
    //     );
    //     expect(totalWeight).eq(1);
    //     expect(trustedWeight).eq(1);
    //   }
    // });

    // it('Should be able to continue to vote on the votes, the later vote is not counted but is tracked', async () => {
    //   for (let i = numerator - 1; i < candidates.length; i++) {
    //     await bridgeContract.connect(candidates[i].bridgeOperator).tryBulkDepositFor(receipts);
    //   }

    //   for (let i = 0; i < receipts.length; i++) {
    //     const vote = await bridgeContract.depositVote(receipts[i].mainchain.chainId, receipts[i].id);
    //     expect(vote.status).eq(VoteStatus.Executed);
    //     const [totalWeight, trustedWeight] = await bridgeContract.getDepositVoteWeight(
    //       mainchainId,
    //       i,
    //       getReceiptHash(receipts[i])
    //     );
    //     expect(totalWeight).eq(numerator);
    //     expect(trustedWeight).eq(numerator);
    //   }
    // });
  });

  describe('Trusted Organization Restriction', () => {
    let snapshotId: any;
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should not approve the vote if there is insufficient trusted votes yet', async () => {
      receipts = [
        {
          id: 0,
          kind: 0,
          mainchain: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: mainchainId,
          },
          ronin: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: network.config.chainId!,
          },
          info: { erc: 0, id: 0, quantity: 1 },
        },
      ];
      receipts.push({ ...receipts[0], id: 1 });

      await bridgeContract
        .connect(candidates[maxPrioritizedValidatorNumber].bridgeOperator)
        .tryBulkDepositFor(receipts);
      const tx = await bridgeContract
        .connect(candidates[maxPrioritizedValidatorNumber + 1].bridgeOperator)
        .tryBulkDepositFor(receipts);
      await expect(tx).not.emit(bridgeContract, 'Deposited');
      const vote = await bridgeContract.depositVote(receipts[0].mainchain.chainId, receipts[0].id);
      expect(vote.status).eq(VoteStatus.Pending);
    });

    // TODO: uncomment below logic

    // it('Should approve the vote if enough trusted votes is submitted', async () => {
    //   const tx = await bridgeContract.connect(candidates[0].bridgeOperator).tryBulkDepositFor(receipts);
    //   await expect(tx).emit(bridgeContract, 'Deposited');

    //   const vote = await bridgeContract.depositVote(receipts[0].mainchain.chainId, receipts[0].id);
    //   expect(vote.status).eq(VoteStatus.Executed);
    // });
  });
});
