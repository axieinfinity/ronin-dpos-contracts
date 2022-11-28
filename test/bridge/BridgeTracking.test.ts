import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
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
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';
import { initTest } from '../helpers/fixture';
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

let receipt: ReceiptStruct;
let period: BigNumberish;
let mainchainWithdrewIds: number[];
let submitWithdrawalSignatures: number[];

const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 4;
const minValidatorStakingAmount = 500;
const numerator = 2;
const denominator = 4;
const mainchainId = 1;

describe('Bridge Tracking test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    candidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 5));

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
        [],
        [[token.address], [token.address]],
        [[mainchainId], [0]],
        [0],
      ])
    );
    bridgeContract = RoninGatewayV2__factory.connect(proxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    // Deploys DPoS contracts
    const { roninGovernanceAdminAddress, stakingContractAddress, validatorContractAddress, bridgeTrackingAddress } =
      await initTest('BridgeTracking')({
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
        },
      });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    bridgeTracking = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, ...trustedOrgs.map((_) => _.governor));

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);

    await TransparentUpgradeableProxyV2__factory.connect(proxy.address, deployer).changeAdmin(governanceAdmin.address);
    await governanceAdminInterface.functionDelegateCalls(
      Array.from(Array(2).keys()).map(() => bridgeContract.address),
      [
        bridgeContract.interface.encodeFunctionData('setBridgeTrackingContract', [bridgeTracking.address]),
        bridgeContract.interface.encodeFunctionData('setValidatorContract', [roninValidatorSet.address]),
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
    expect(await roninValidatorSet.getBridgeOperators()).eql(candidates.map((v) => v.bridgeOperator.address));
  });

  it('Should be able to get contract configs correctly', async () => {
    expect(await bridgeTracking.bridgeContract()).eq(bridgeContract.address);
    expect(await bridgeContract.bridgeTrackingContract()).eq(bridgeTracking.address);
    expect(await bridgeContract.validatorContract()).eq(roninValidatorSet.address);
    expect(await bridgeContract.getMainchainToken(token.address, mainchainId)).eql([0, token.address]);
    expect(await roninValidatorSet.currentPeriod()).eq(period);
  });

  it('Should not record the receipts which is not approved yet', async () => {
    receipt = {
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
    };

    submitWithdrawalSignatures = [0, 1, 2, 3, 4, 5];
    mainchainWithdrewIds = [6, 7, 8, 9, 10];

    await bridgeContract.connect(candidates[0].bridgeOperator).depositFor(receipt);
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

  it('Should be able to record the votes/ballots when the receipts are already approved', async () => {
    {
      const tx = await bridgeContract.connect(candidates[1].bridgeOperator).depositFor(receipt);
      await expect(tx).emit(bridgeContract, 'Deposited').withArgs(anyValue, anyValue);
    }
    {
      const tx = await bridgeContract
        .connect(candidates[1].bridgeOperator)
        .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);
      await expect(tx).emit(bridgeContract, 'MainchainWithdrew').withArgs(anyValue, anyValue);
    }
    await bridgeContract.connect(candidates[1].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );

    // Should skips for the method `bulkSubmitWithdrawalSignatures` because no one requests these withdrawals
    expect(await bridgeTracking.totalVotes(period)).eq(1 + mainchainWithdrewIds.length);
    expect(await bridgeTracking.totalBallots(period)).eq((1 + mainchainWithdrewIds.length) * 2);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
  });

  it('Should still be able to record for those who vote once the request is approved', async () => {
    await bridgeContract.connect(candidates[2].bridgeOperator).tryBulkDepositFor([receipt]);
    await bridgeContract
      .connect(candidates[2].bridgeOperator)
      .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);

    expect(await bridgeTracking.totalVotes(period)).eq(1 + mainchainWithdrewIds.length);
    expect(await bridgeTracking.totalBallots(period)).eq((1 + mainchainWithdrewIds.length) * 3);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
  });

  it('Should not record in the next period', async () => {
    await network.provider.send('evm_increaseTime', [86400]);
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const newPeriod = await roninValidatorSet.currentPeriod();
    expect(newPeriod).not.eq(period);

    await bridgeContract.connect(candidates[3].bridgeOperator).depositFor(receipt);
    await bridgeContract
      .connect(candidates[3].bridgeOperator)
      .tryBulkAcknowledgeMainchainWithdrew(mainchainWithdrewIds);

    expect(await bridgeTracking.totalVotes(period)).eq(1 + mainchainWithdrewIds.length);
    expect(await bridgeTracking.totalBallots(period)).eq((1 + mainchainWithdrewIds.length) * 3);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(
      1 + mainchainWithdrewIds.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(0);

    period = newPeriod;
    expect(await bridgeTracking.totalVotes(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallots(newPeriod)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[0].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[1].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[2].bridgeOperator.address)).eq(0);
    expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[3].bridgeOperator.address)).eq(0);
  });

  it('Should be able to request withdrawal and record voting for submitting signatures', async () => {
    await token.mint(deployer.address, 1_000_000);
    await token.connect(deployer).approve(bridgeContract.address, ethers.constants.MaxUint256);

    await bridgeContract.bulkRequestWithdrawalFor(
      submitWithdrawalSignatures.map(() => ({
        recipientAddr: deployer.address,
        tokenAddr: token.address,
        info: receipt.info,
      })),
      mainchainId
    );

    await bridgeContract.connect(candidates[0].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
    await bridgeContract.connect(candidates[1].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
    await bridgeContract.connect(candidates[2].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
    await bridgeContract.connect(candidates[3].bridgeOperator).bulkSubmitWithdrawalSignatures(
      submitWithdrawalSignatures,
      submitWithdrawalSignatures.map(() => [])
    );
    expect(await bridgeTracking.totalVotes(period)).eq(submitWithdrawalSignatures.length);
    expect(await bridgeTracking.totalBallots(period)).eq(submitWithdrawalSignatures.length * 4);
    expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(
      submitWithdrawalSignatures.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(
      submitWithdrawalSignatures.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(
      submitWithdrawalSignatures.length
    );
    expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(
      submitWithdrawalSignatures.length
    );
  });
});
