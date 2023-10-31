import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  BridgeTracking,
  BridgeTracking__factory,
  ERC20PresetMinterPauser__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  RoninBridgeManager,
  RoninBridgeManager__factory,
  RoninGatewayV3,
  RoninGatewayV3__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
} from '../../../src/types';
import { ERC20PresetMinterPauser } from '../../../src/types/ERC20PresetMinterPauser';
import { ReceiptStruct } from '../../../src/types/IRoninGatewayV3';
import { DEFAULT_ADDRESS } from '../../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
import { ContractType, mineBatchTxs } from '../helpers/utils';
import { BridgeManagerInterface } from '../../../src/script/bridge-admin-interface';
import { TargetOption } from '../../../src/script/proposal';
import { OperatorTuple, createManyOperatorTuples } from '../helpers/address-set-types/operator-tuple-type';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: ValidatorCandidateAddressSet[];
let operatorTuples: OperatorTuple[];
let signers: SignerWithAddress[];

let bridgeContract: RoninGatewayV3;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;
let token: ERC20PresetMinterPauser;
let bridgeManager: RoninBridgeManager;
let bridgeAdminInterface: BridgeManagerInterface;

let period: BigNumberish;
let receipts: ReceiptStruct[];
let mainchainWithdrewIds: number[];
let submitWithdrawalSignatures: number[];

const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 4;
const minValidatorStakingAmount = 500;
const numerator = 2;
const denominator = 4;
const trustedNumerator = 0;
const trustedDenominator = 1;
const mainchainId = 1;
const numberOfBlocksInEpoch = 600;

const operatorNumber = 4;
const bridgeAdminNumerator = 2;
const bridgeAdminDenominator = operatorNumber;

describe('[Integration] Bridge Tracking test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    candidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    trustedOrgs = createManyTrustedOrganizationAddressSets([
      ...signers.slice(0, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
    ]);
    operatorTuples = createManyOperatorTuples(signers.splice(0, operatorNumber * 2));

    // Deploys bridge contracts
    token = await new ERC20PresetMinterPauser__factory(deployer).deploy('ERC20', 'ERC20');
    const bridgeLogic = await new RoninGatewayV3__factory(deployer).deploy();
    const bridgeProxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      bridgeLogic.address,
      deployer.address,
      bridgeLogic.interface.encodeFunctionData('initialize', [
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

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      validatorContractAddress,
      bridgeTrackingAddress,
      roninBridgeManagerAddress,
      bridgeSlashAddress,
      bridgeRewardAddress,
      fastFinalityTrackingAddress,
    } = await initTest('ActionBridgeTracking')({
      bridgeContract: bridgeProxy.address,
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
      bridgeManagerArguments: {
        numerator: bridgeAdminNumerator,
        denominator: bridgeAdminDenominator,
        members: operatorTuples.map((_) => {
          return {
            operator: _.operator.address,
            governor: _.governor.address,
            weight: 100,
          };
        }),
      },
    });

    bridgeContract = RoninGatewayV3__factory.connect(bridgeProxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    bridgeTracking = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    bridgeManager = RoninBridgeManager__factory.connect(roninBridgeManagerAddress, deployer);
    bridgeAdminInterface = new BridgeManagerInterface(
      bridgeManager,
      network.config.chainId!,
      undefined,
      ...operatorTuples.map((_) => _.governor)
    );

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

    await TransparentUpgradeableProxyV2__factory.connect(bridgeContract.address, deployer).changeAdmin(
      bridgeManager.address
    );
    await bridgeAdminInterface.functionDelegateCallsGlobal(
      [TargetOption.GatewayContract],
      [
        bridgeContract.interface.encodeFunctionData('setContract', [
          ContractType.BRIDGE_TRACKING,
          bridgeTracking.address,
        ]),
      ]
    );
    await governanceAdminInterface.functionDelegateCalls(
      [bridgeTracking.address, governanceAdmin.address],
      [
        bridgeTracking.interface.encodeFunctionData('setContract', [ContractType.BRIDGE, bridgeContract.address]),
        governanceAdmin.interface.encodeFunctionData('changeProxyAdmin', [
          bridgeTracking.address,
          bridgeManager.address,
        ]),
      ]
    );

    // Set up bridge manager for current gateway contract
    await bridgeContract.initializeV3(bridgeManager.address);
    expect(await bridgeManager.getBridgeOperators()).deep.equal(operatorTuples.map((v) => v.operator.address));

    // Apply candidates and double check the bridge operators
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
    expect(period).gt(0);

    // InitV3 after the period 0
    await bridgeTracking.initializeV3(
      bridgeManager.address,
      bridgeSlashAddress,
      bridgeRewardAddress,
      governanceAdmin.address
    );
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  it('Should be able to get contract configs correctly', async () => {
    expect(await bridgeTracking.getContract(ContractType.BRIDGE)).eq(bridgeContract.address);
    // expect(await bridgeTracking.getContract(ContractType.VALIDATOR)).eq(roninValidatorSet.address);
    // expect(await bridgeContract.getContract(ContractType.BRIDGE_TRACKING)).eq(bridgeTracking.address);
    // expect(await bridgeContract.getMainchainToken(token.address, mainchainId)).deep.equal([0, token.address]);
    // expect(await roninValidatorSet.currentPeriod()).eq(period);
  });

  it('Should not record the receipts which is not approved yet', async () => {
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
    submitWithdrawalSignatures = [0, 1, 2, 3, 4, 5];
    mainchainWithdrewIds = [6, 7, 8, 9, 10];

    await bridgeContract.connect(operatorTuples[0].operator).tryBulkDepositFor(receipts);
    await bridgeContract.connect(operatorTuples[0].operator).tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(operatorTuples[0].operator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    expect(await bridgeTracking.totalVote(period)).eq(0);
    expect(await bridgeTracking.totalBallot(period)).eq(0);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[0].operator.address)).eq(0);
  });

  it('Should be able to approve the receipts', async () => {
    {
      const tx = await bridgeContract.connect(operatorTuples[1].operator).tryBulkDepositFor(receipts);
      await expect(tx).emit(bridgeContract, 'Deposited');
    }
    {
      const tx = await bridgeContract
        .connect(operatorTuples[1].operator)
        .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
      await expect(tx).emit(bridgeContract, 'MainchainWithdrew');
    }
    await bridgeContract.connect(operatorTuples[1].operator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
  });

  it('Should not record the approved receipts once the epoch is not yet wrapped up', async () => {
    expect(await bridgeTracking.totalVote(period)).eq(0);
    expect(await bridgeTracking.totalBallot(period)).eq(0);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[0].operator.address)).eq(0);
  });

  it('Should be able to record the approved votes/ballots when the epoch is wrapped up', async () => {
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVote(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallot(period)).eq(expectTotalVotes * 2);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[0].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[1].operator.address)).eq(expectTotalVotes);
  });

  it('Should still be able to record for those who vote lately once the request is approved', async () => {
    await bridgeContract.connect(operatorTuples[2].operator).tryBulkDepositFor(receipts);
    await bridgeContract.connect(operatorTuples[2].operator).tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(operatorTuples[2].operator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVote(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallot(period)).eq(expectTotalVotes * 3);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[0].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[1].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[2].operator.address)).eq(expectTotalVotes);
  });

  it('Should not record in the next period', async () => {
    await EpochController.setTimestampToPeriodEnding();
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const newPeriod = await roninValidatorSet.currentPeriod();
    expect(newPeriod).not.eq(period);

    await bridgeContract.connect(operatorTuples[3].operator).tryBulkDepositFor(receipts);
    await bridgeContract.connect(operatorTuples[3].operator).tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(operatorTuples[3].operator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVote(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallot(period)).eq(expectTotalVotes * 3);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[0].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[1].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[2].operator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotOf(period, operatorTuples[3].operator.address)).eq(0);

    period = newPeriod;
    expect(await bridgeTracking.totalVote(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallot(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallotOf(newPeriod, operatorTuples[0].operator.address)).eq(0);
    expect(await bridgeTracking.totalBallotOf(newPeriod, operatorTuples[1].operator.address)).eq(0);
    expect(await bridgeTracking.totalBallotOf(newPeriod, operatorTuples[2].operator.address)).eq(0);
    expect(await bridgeTracking.totalBallotOf(newPeriod, operatorTuples[3].operator.address)).eq(0);
  });
});
