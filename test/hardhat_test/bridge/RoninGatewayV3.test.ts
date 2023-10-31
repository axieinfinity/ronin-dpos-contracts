import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { getReceiptHash } from '../../../src/script/bridge';

import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { TargetOption, VoteStatus } from '../../../src/script/proposal';
import {
  BridgeTracking,
  BridgeTracking__factory,
  ERC20PresetMinterPauser__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  MockRoninGatewayV3Extended,
  MockRoninGatewayV3Extended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
  RoninBridgeManager__factory,
  RoninBridgeManager,
} from '../../../src/types';
import { ERC20PresetMinterPauser } from '../../../src/types/ERC20PresetMinterPauser';
import { ReceiptStruct } from '../../../src/types/IRoninGatewayV3';
import { DEFAULT_ADDRESS } from '../../../src/utils';
import { initTest } from '../helpers/fixture';
import { ContractType, mineBatchTxs } from '../helpers/utils';
import { OperatorTuple, createManyOperatorTuples } from '../helpers/address-set-types/operator-tuple-type';
import { BridgeManagerInterface } from '../../../src/script/bridge-admin-interface';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let operatorTuples: OperatorTuple[];
let signers: SignerWithAddress[];

let bridgeContract: MockRoninGatewayV3Extended;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let bridgeManager: RoninBridgeManager;
let governanceAdmin: RoninGovernanceAdmin;
let bridgeAdminInterface: BridgeManagerInterface;
let token: ERC20PresetMinterPauser;

let receipts: ReceiptStruct[];

const maxValidatorNumber = 6;
const maxPrioritizedValidatorNumber = maxValidatorNumber - 2;
const minValidatorStakingAmount = 500;
const operatorNumber = 3;

// only requires 3 operator for the proposal to pass
const numerator = 3;
const denominator = maxValidatorNumber;

// requires 1 trusted operators for the proposal to pass
const trustedNumerator = 1;
const trustedDenominator = maxPrioritizedValidatorNumber;

// requires 2/3 operator for the proposal to pass
const bridgeAdminNumerator = 2;
const bridgeAdminDenominator = operatorNumber;

const mainchainId = 1;
const numberOfBlocksInEpoch = 600;

describe('Ronin Gateway V2 test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    operatorTuples = createManyOperatorTuples(signers.splice(0, operatorNumber * 2));

    // Deploys bridge contracts
    token = await new ERC20PresetMinterPauser__factory(deployer).deploy('ERC20', 'ERC20');
    const gatewayLogic = await new MockRoninGatewayV3Extended__factory(deployer).deploy();
    const gatewayProxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      gatewayLogic.address,
      deployer.address,
      gatewayLogic.interface.encodeFunctionData('initialize', [
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
    bridgeContract = MockRoninGatewayV3Extended__factory.connect(gatewayProxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      bridgeTrackingAddress,
      roninBridgeManagerAddress,
      roninTrustedOrganizationAddress,
    } = await initTest('RoninGatewayV3')({
      bridgeContract: bridgeContract.address,
      stakingArguments: {
        minValidatorStakingAmount,
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

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    bridgeTracking = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    bridgeManager = RoninBridgeManager__factory.connect(roninBridgeManagerAddress, deployer);
    bridgeAdminInterface = new BridgeManagerInterface(
      bridgeManager,
      network.config.chainId!,
      undefined,
      ...operatorTuples.map((_) => _.governor)
    );

    await TransparentUpgradeableProxyV2__factory.connect(gatewayProxy.address, deployer).changeAdmin(
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

    await bridgeContract.initializeV3(roninBridgeManagerAddress);
    expect(await bridgeManager.getBridgeOperators()).deep.equal(operatorTuples.map((v) => v.operator.address));
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  describe('Voting Test', () => {
    let snapshotId: any;
    before(async () => {
      snapshotId = await network.provider.send('evm_snapshot');
    });

    after(async () => {
      await network.provider.send('evm_revert', [snapshotId]);
    });

    it('Should be able to bulk deposits using bridge operator accounts', async () => {
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
          info: { erc: 0, id: 0, quantity: 100 },
        },
      ];
      receipts.push({ ...receipts[0], id: 1 });

      for (let i = 0; i < bridgeAdminNumerator - 1; i++) {
        const tx = await bridgeContract.connect(operatorTuples[i].operator).tryBulkDepositFor(receipts);
        await expect(tx).not.emit(bridgeContract, 'Deposited');
      }

      for (let i = 0; i < receipts.length; i++) {
        const vote = await bridgeContract.depositVote(receipts[i].mainchain.chainId, receipts[i].id);
        expect(vote.status).eq(VoteStatus.Pending);
        const totalWeight = await bridgeContract.getDepositVoteWeight(mainchainId, i, getReceiptHash(receipts[i]));
        expect(totalWeight).eq((bridgeAdminNumerator - 1) * 100);
      }
    });

    it.skip('Should be able to update the vote weights when a bridge operator exited', async () => {
      // await stakingContract.connect(candidates[0].poolAdmin).requestEmergencyExit(candidates[0].consensusAddr.address);
      // await mineBatchTxs(async () => {
      //   await roninValidatorSet.endEpoch();
      //   await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      // });
      {
        const totalWeight = await bridgeContract.getDepositVoteWeight(mainchainId, 0, getReceiptHash(receipts[0]));
        expect(totalWeight).eq(1);
      }
      {
        const totalWeight = await bridgeContract.getDepositVoteWeight(mainchainId, 1, getReceiptHash(receipts[1]));
        expect(totalWeight).eq(1);
      }
    });

    it('Should be able to continue to vote on the votes, the later vote is not counted but is tracked', async () => {
      for (let i = bridgeAdminNumerator - 1; i < operatorTuples.length; i++) {
        await bridgeContract.connect(operatorTuples[i].operator).tryBulkDepositFor(receipts);
      }

      for (let i = 0; i < receipts.length; i++) {
        const vote = await bridgeContract.depositVote(receipts[i].mainchain.chainId, receipts[i].id);
        expect(vote.status).eq(VoteStatus.Executed);
        const totalWeight = await bridgeContract.getDepositVoteWeight(mainchainId, i, getReceiptHash(receipts[i]));
        expect(totalWeight).eq(bridgeAdminNumerator * 100);
      }
    });
  });
});
