import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import {
  BridgeTracking,
  BridgeTracking__factory,
  MockGatewayForTracking,
  MockGatewayForTracking__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
} from '../../src/types';
import { DEFAULT_ADDRESS } from '../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
import { getRole, mineBatchTxs } from '../helpers/utils';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: ValidatorCandidateAddressSet[];
let signers: SignerWithAddress[];

let mockGateway: MockGatewayForTracking;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let period: BigNumberish;

const maxValidatorNumber = 6;
const maxPrioritizedValidatorNumber = 4;
const minValidatorStakingAmount = 500;
const numerator = 2;
const denominator = 4;
const numberOfBlocksInEpoch = 600;

describe('Bridge Tracking test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    candidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    trustedOrgs = createManyTrustedOrganizationAddressSets([
      ...signers.slice(0, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
      ...signers.splice(maxValidatorNumber * 5, maxPrioritizedValidatorNumber),
    ]);

    // Deploys DPoS contracts
    const {
      roninGovernanceAdminAddress,
      stakingContractAddress,
      validatorContractAddress,
      bridgeTrackingAddress,
      profileAddress,
    } = await initTest('BridgeTracking')({
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

    mockGateway = await new MockGatewayForTracking__factory(deployer).deploy(bridgeTrackingAddress);
    await mockGateway.deployed();

    await governanceAdminInterface.functionDelegateCalls(
      [bridgeTracking.address],
      [bridgeTracking.interface.encodeFunctionData('setContract', [getRole('BRIDGE_CONTRACT'), mockGateway.address])]
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
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  describe('Config test', async () => {
    it('Should be able to get contract configs correctly', async () => {
      expect(await bridgeTracking.getContract(getRole('BRIDGE_CONTRACT'))).eq(mockGateway.address);
      expect(await mockGateway.getContract(getRole('BRIDGE_TRACKING_CONTRACT'))).eq(bridgeTracking.address);
      expect(await roninValidatorSet.currentPeriod()).eq(period);
    });
  });

  describe('Epoch e-2 test: Vote is approved NOT in the last epoch', async () => {
    let receipt: any;
    before(async () => {
      receipt = {
        id: 0,
        kind: 0,
      };
    });

    describe('Epoch e-2: Vote & Approve & Vote.', async () => {
      it('Should not record the receipts which is not approved yet', async () => {
        await mockGateway.sendBallot(
          receipt.kind,
          receipt.id,
          [candidates[0], candidates[1]].map((_) => _.bridgeOperator.address)
        );

        expect(await bridgeTracking.totalVotes(period)).eq(0);
        expect(await bridgeTracking.totalBallots(period)).eq(0);
        expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      });

      it.skip('Should be able to approve the receipts', async () => {
        await mockGateway.sendApprovedVote(receipt.kind, receipt.id);
      });

      it('Should not record the approved receipts once the epoch is not yet wrapped up', async () => {
        expect(await bridgeTracking.totalVotes(period)).eq(0);
        expect(await bridgeTracking.totalBallots(period)).eq(0);
        expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      });
    });

    describe('Epoch e-1: Continue voting for the vote of e-2', async () => {
      // TODO: uncomment below logic
      // it('Should be able to record the approved votes/ballots when the epoch is wrapped up (value from buffer metric)', async () => {
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   const expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 2);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      // });
      // it('Should still be able to record for those who vote lately once the request is approved', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[2]].map((_) => _.bridgeOperator.address)
      //   );
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   const expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      // });
    });

    // TODO: uncomment below logic

    // describe('Epoch e (first epoch of new period): Continue voting for vote in e-2', async () => {
    //   it('Should not record in the next period', async () => {
    //     await EpochController.setTimestampToPeriodEnding();
    //     await mineBatchTxs(async () => {
    //       await roninValidatorSet.endEpoch();
    //       await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    //     });
    //     const newPeriod = await roninValidatorSet.currentPeriod();
    //     expect(newPeriod).not.eq(period);

    //     await mockGateway.sendBallot(
    //       receipt.kind,
    //       receipt.id,
    //       [candidates[3]].map((_) => _.bridgeOperator.address)
    //     );

    //     let expectTotalVotes = 1;
    //     expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
    //     expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
    //     expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
    //     expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
    //     expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
    //     expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(0);

    //     period = newPeriod;
    //     expect(await bridgeTracking.totalVotes(newPeriod)).eq(0);
    //     expect(await bridgeTracking.totalBallots(newPeriod)).eq(0);
    //     expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[0].bridgeOperator.address)).eq(0);
    //     expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[1].bridgeOperator.address)).eq(0);
    //     expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[2].bridgeOperator.address)).eq(0);
    //     expect(await bridgeTracking.totalBallotsOf(newPeriod, candidates[3].bridgeOperator.address)).eq(0);
    //   });
    // });
  });

  describe('Epoch e-1 test: Vote is approved in the last epoch of period', async () => {
    let receipt: any;
    before(async () => {
      receipt = {
        id: 1,
        kind: 1,
      };
    });

    describe('Epoch e-1: Vote & Approve & Vote', async () => {
      // TODO: uncomment below logic
      // it('Should not record when not approved yet. Vote in last epoch (e-1).', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[0], candidates[1]].map((_) => _.bridgeOperator.address)
      //   );
      //   expect(await bridgeTracking.totalVotes(period)).eq(0);
      //   expect(await bridgeTracking.totalBallots(period)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(0);
      // });
      // it('Should not record when approve. Approve in last epoch (e-1).', async () => {
      //   await mockGateway.sendApprovedVote(receipt.kind, receipt.id);
      //   expect(await bridgeTracking.totalVotes(period)).eq(0);
      //   expect(await bridgeTracking.totalBallots(period)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(0);
      // });
      // it('Should not record even after approved. Vote in last epoch (e-1).', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[2]].map((_) => _.bridgeOperator.address)
      //   );
      //   expect(await bridgeTracking.totalVotes(period)).eq(0);
      //   expect(await bridgeTracking.totalBallots(period)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(0);
      // });
    });

    describe('Epoch e: vote', async () => {
      // TODO: uncomment below logic
      // it('Should not record for current period metric when wrapping up period. Query in next epoch (e), for current period (p-1): return 0.', async () => {
      //   await EpochController.setTimestampToPeriodEnding();
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   const newPeriod = await roninValidatorSet.currentPeriod();
      //   expect(newPeriod).not.eq(period);
      //   expect(await bridgeTracking.totalVotes(period)).eq(0);
      //   expect(await bridgeTracking.totalBallots(period)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(0);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(0);
      //   period = newPeriod;
      //   let expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      // });
      // it('Should record for the buffer metric when wrapping up period. Query in next epoch (e), for next period (p): return >0 (buffer).', async () => {
      //   let expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 3);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      // });
      // it('Should record new ballot for the buffer metric ', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[3]].map((_) => _.bridgeOperator.address)
      //   );
      //   let expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 4);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 4);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      // });
    });

    describe('Epoch 2e-1: vote', async () => {
      // it('Should record new ballot for the buffer metric ', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[4]].map((_) => _.bridgeOperator.address)
      //   );
      //   let expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 5);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[4].bridgeOperator.address)).eq(expectTotalVotes);
      //   await EpochController.setTimestampToPeriodEnding();
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 5);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[4].bridgeOperator.address)).eq(expectTotalVotes);
      // });
    });

    describe('Epoch 3e: vote', async () => {
      // TODO: uncomment below logic
      // it('Should not record new ballot. And the period metric is finalized as in epoch 2e-1.', async () => {
      //   await mockGateway.sendBallot(
      //     receipt.kind,
      //     receipt.id,
      //     [candidates[5]].map((_) => _.bridgeOperator.address)
      //   );
      //   let expectTotalVotes = 1;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 5);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[4].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[5].bridgeOperator.address)).eq(0);
      //   await EpochController.setTimestampToPeriodEnding();
      //   await mineBatchTxs(async () => {
      //     await roninValidatorSet.endEpoch();
      //     await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      //   });
      //   const newPeriod = await roninValidatorSet.currentPeriod();
      //   expect(newPeriod).not.eq(period);
      //   period = newPeriod;
      // });
      // it('Should the metric of the new period get reset', async () => {
      //   let expectTotalVotes = 0;
      //   expect(await bridgeTracking.totalVotes(period)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallots(period)).eq(expectTotalVotes * 4);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[0].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[1].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[2].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[3].bridgeOperator.address)).eq(expectTotalVotes);
      //   expect(await bridgeTracking.totalBallotsOf(period, candidates[4].bridgeOperator.address)).eq(expectTotalVotes);
      // });
    });
  });
});
