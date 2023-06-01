import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import {
  BridgeTracking,
  BridgeTracking__factory,
  ERC20PresetMinterPauser__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  RoninGatewayV2,
  RoninGatewayV2__factory,
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
import { EpochController } from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: ValidatorCandidateAddressSet[];
let signers: SignerWithAddress[];

let bridgeContract: RoninGatewayV2;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;
let token: ERC20PresetMinterPauser;

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

describe('[Integration] Bridge Tracking test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    candidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    trustedOrgs = createManyTrustedOrganizationAddressSets([
      ...signers.slice(0, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
    ]);

    // Deploys bridge contracts
    token = await new ERC20PresetMinterPauser__factory(deployer).deploy('ERC20', 'ERC20');
    const logic = await new RoninGatewayV2__factory(deployer).deploy();
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
    bridgeContract = RoninGatewayV2__factory.connect(proxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      validatorContractAddress,
      bridgeTrackingAddress,
      roninTrustedOrganizationAddress,
    } = await initTest('ActionBridgeTracking')({
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
    await roninValidatorSet.initEpoch();

    await TransparentUpgradeableProxyV2__factory.connect(proxy.address, deployer).changeAdmin(governanceAdmin.address);
    await governanceAdminInterface.functionDelegateCalls(
      Array.from(Array(3).keys()).map(() => bridgeContract.address),
      [
        bridgeContract.interface.encodeFunctionData('setBridgeTrackingContract', [bridgeTracking.address]),
        bridgeContract.interface.encodeFunctionData('setValidatorContract', [roninValidatorSet.address]),
        bridgeContract.interface.encodeFunctionData('setRoninTrustedOrganizationContract', [
          roninTrustedOrganizationAddress,
        ]),
      ]
    );

    // Apply candidates and double check the bridge operators
    for (let i = 0; i < candidates.length; i++) {
      await stakingContract
        .connect(candidates[i].poolAdmin)
        .applyValidatorCandidate(
          candidates[i].candidateAdmin.address,
          candidates[i].consensusAddr.address,
          candidates[i].treasuryAddr.address,
          candidates[i].bridgeOperator.address,
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
    expect((await roninValidatorSet.getBridgeOperators())._bridgeOperatorList).deep.equal(
      candidates.map((v) => v.bridgeOperator.address)
    );
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  it('Should be able to get contract configs correctly', async () => {
    expect(await bridgeTracking.bridgeContract()).eq(bridgeContract.address);
    expect(await bridgeContract.bridgeTrackingContract()).eq(bridgeTracking.address);
    expect(await bridgeContract.validatorContract()).eq(roninValidatorSet.address);
    expect(await bridgeContract.getMainchainToken(token.address, mainchainId)).deep.equal([0, token.address]);
    expect(await roninValidatorSet.currentPeriod()).eq(period);
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

    await bridgeContract.connect(candidates[0].bridgeOperator).tryBulkDepositFor(receipts);
    await bridgeContract
      .connect(candidates[0].bridgeOperator)
      .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(candidates[0].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    expect(await bridgeTracking.totalVotes(period)).eq(0);
    expect(await bridgeTracking.totalBallots(period)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
  });

  it('Should be able to approve the receipts', async () => {
    {
      const tx = await bridgeContract.connect(candidates[1].bridgeOperator).tryBulkDepositFor(receipts);
      await expect(tx).emit(bridgeContract, 'Deposited');
    }
    {
      const tx = await bridgeContract
        .connect(candidates[1].bridgeOperator)
        .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
      await expect(tx).emit(bridgeContract, 'MainchainWithdrew');
    }
    await bridgeContract.connect(candidates[1].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
  });

  it('Should not record the approved receipts once the epoch is not yet wrapped up', async () => {
    expect(await bridgeTracking.totalVotes(period)).eq(0);
    expect(await bridgeTracking.totalBallots(period)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
  });

  it('Should be able to record the approved votes/ballots when the epoch is wrapped up', async () => {
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 2);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
  });

  it('Should still be able to record for those who vote lately once the request is approved', async () => {
    await bridgeContract.connect(candidates[2].bridgeOperator).tryBulkDepositFor(receipts);
    await bridgeContract
      .connect(candidates[2].bridgeOperator)
      .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(candidates[2].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
  });

  it('Should not record in the next period', async () => {
    await EpochController.setTimestampToPeriodEnding();
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const newPeriod = await roninValidatorSet.currentPeriod();
    expect(newPeriod).not.eq(period);

    await bridgeContract.connect(candidates[3].bridgeOperator).tryBulkDepositFor(receipts);
    await bridgeContract
      .connect(candidates[3].bridgeOperator)
      .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
    await bridgeContract.connect(candidates[3].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    const expectTotalVotes = mainchainWithdrewIds.length + submitWithdrawalSignatures.length + receipts.length;
    expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(0);

    period = newPeriod;
    expect(await bridgeTracking.totalVotes(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallots(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[0].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[1].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[2].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[3].bridgeOperator.address)).eq(0);
  });
});
