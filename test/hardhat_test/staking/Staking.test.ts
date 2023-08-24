import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';

import {
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2,
  TransparentUpgradeableProxyV2__factory,
} from '../../../src/types';
import { MockValidatorSet__factory } from '../../../src/types/factories/MockValidatorSet__factory';
import { StakingVesting__factory } from '../../../src/types/factories/StakingVesting__factory';
import { MockValidatorSet } from '../../../src/types/MockValidatorSet';
import {
  createManyValidatorCandidateAddressSets,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types/validator-candidate-set-type';
import { getLastBlockTimestamp } from '../helpers/utils';

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;

let proxyAdmin: SignerWithAddress;
let userA: SignerWithAddress;
let userB: SignerWithAddress;
let poolAddrSet: ValidatorCandidateAddressSet;
let otherPoolAddrSet: ValidatorCandidateAddressSet;
let anotherActivePoolSet: ValidatorCandidateAddressSet;
let sparePoolAddrSet: ValidatorCandidateAddressSet;

let proxyContract: TransparentUpgradeableProxyV2;
let validatorContract: MockValidatorSet;
let stakingContract: Staking;
let signers: SignerWithAddress[];
let validatorCandidates: ValidatorCandidateAddressSet[];

const ONE_DAY = 60 * 60 * 24;

const minValidatorStakingAmount = BigNumber.from(2_000_000);
const maxValidatorCandidate = 50;
const numberOfBlocksInEpoch = 2;
const cooldownSecsToUndelegate = 3 * 86400;
const waitingSecsToRevoke = 7 * 86400;
const maxCommissionRate = 30_00;
const defaultMinCommissionRate = 0;
const minEffectiveDaysOnwards = 7;
const numberOfCandidate = 4;

describe('Staking test', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, userA, userB, ...signers] = await ethers.getSigners();
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, numberOfCandidate * 3));
    sparePoolAddrSet = validatorCandidates.splice(validatorCandidates.length - 1)[0];

    const stakingVestingContract = await new StakingVesting__factory(deployer).deploy();
    const nonce = await deployer.getTransactionCount();
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    validatorContract = await new MockValidatorSet__factory(deployer).deploy(
      stakingContractAddr,
      ethers.constants.AddressZero,
      stakingVestingContract.address,
      maxValidatorCandidate,
      numberOfBlocksInEpoch,
      minEffectiveDaysOnwards
    );
    await validatorContract.deployed();
    const logicContract = await new Staking__factory(deployer).deploy();
    await logicContract.deployed();
    proxyContract = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        validatorContract.address,
        minValidatorStakingAmount,
        maxCommissionRate,
        cooldownSecsToUndelegate,
        waitingSecsToRevoke,
      ])
    );
    await proxyContract.deployed();
    stakingContract = Staking__factory.connect(proxyContract.address, deployer);
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  describe('Validator candidate test', () => {
    it('Should not be able to propose validator with insufficient amount', async () => {
      await expect(
        stakingContract.applyValidatorCandidate(userA.address, userA.address, userA.address, 1)
      ).revertedWithCustomError(stakingContract, 'ErrInsufficientStakingAmount');
    });

    it('Should not be able to propose validator with duplicated address', async () => {
      let candidate = validatorCandidates[1];

      const tx = stakingContract
        .connect(candidate.poolAdmin)
        .applyValidatorCandidate(
          candidate.candidateAdmin.address,
          candidate.consensusAddr.address,
          candidate.consensusAddr.address,
          1,
          /* 0.01% */ { value: minValidatorStakingAmount.mul(2) }
        );
      await expect(tx).revertedWithCustomError(stakingContract, 'ErrThreeInteractionAddrsNotEqual');
    });

    it('Should be able to propose validator with sufficient amount', async () => {
      for (let i = 0; i < validatorCandidates.length; i++) {
        const candidate = validatorCandidates[i];
        const tx = await stakingContract
          .connect(candidate.poolAdmin)
          .applyValidatorCandidate(
            candidate.candidateAdmin.address,
            candidate.consensusAddr.address,
            candidate.treasuryAddr.address,
            1,
            /* 0.01% */ { value: minValidatorStakingAmount.mul(2) }
          );
        await expect(tx)
          .emit(stakingContract, 'PoolApproved')
          .withArgs(candidate.consensusAddr.address, candidate.poolAdmin.address);
      }

      poolAddrSet = validatorCandidates[0];
      expect(await stakingContract.getStakingTotal(poolAddrSet.consensusAddr.address)).eq(
        minValidatorStakingAmount.mul(2)
      );
    });

    it('Should not be able to propose validator (existent consensus address) again', async () => {
      await expect(
        stakingContract
          .connect(sparePoolAddrSet.poolAdmin)
          .applyValidatorCandidate(
            sparePoolAddrSet.candidateAdmin.address,
            poolAddrSet.consensusAddr.address,
            sparePoolAddrSet.treasuryAddr.address,
            0,
            {
              value: minValidatorStakingAmount,
            }
          )
      ).revertedWithCustomError(validatorContract, 'ErrExistentCandidate');
    });

    it('Should not be able to stake with empty value', async () => {
      await expect(stakingContract.stake(poolAddrSet.consensusAddr.address, { value: 0 })).revertedWithCustomError(
        stakingContract,
        'ErrZeroValue'
      );
    });

    it('Should not be able to call stake/unstake when the method is not the pool admin', async () => {
      await expect(stakingContract.stake(poolAddrSet.consensusAddr.address, { value: 1 })).revertedWithCustomError(
        stakingContract,
        'ErrOnlyPoolAdminAllowed'
      );

      await expect(stakingContract.unstake(poolAddrSet.consensusAddr.address, 1)).revertedWithCustomError(
        stakingContract,
        'ErrOnlyPoolAdminAllowed'
      );
    });

    it('Should be able to stake as a validator candidate', async () => {
      const tx = await stakingContract
        .connect(poolAddrSet.poolAdmin)
        .stake(poolAddrSet.consensusAddr.address, { value: 1 });
      await expect(tx!).emit(stakingContract, 'Staked').withArgs(poolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingTotal(poolAddrSet.consensusAddr.address)).eq(
        minValidatorStakingAmount.mul(2).add(1)
      );
    });

    it('Should not be able to unstake due to cooldown restriction', async () => {
      await expect(
        stakingContract.connect(poolAddrSet.poolAdmin).unstake(poolAddrSet.consensusAddr.address, 1)
      ).revertedWithCustomError(stakingContract, 'ErrUnstakeTooEarly');
    });

    it('Should not be able to unstake after cooldown', async () => {
      await network.provider.send('evm_increaseTime', [cooldownSecsToUndelegate + 1]);
      const tx = await stakingContract.connect(poolAddrSet.poolAdmin).unstake(poolAddrSet.consensusAddr.address, 1);
      await expect(tx!).emit(stakingContract, 'Unstaked').withArgs(poolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingTotal(poolAddrSet.consensusAddr.address)).eq(
        minValidatorStakingAmount.mul(2)
      );
      expect(
        await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, poolAddrSet.poolAdmin.address)
      ).eq(minValidatorStakingAmount.mul(2));
    });

    it('[Delegator] Should be able to delegate/undelegate to a validator candidate', async () => {
      await stakingContract.delegate(poolAddrSet.consensusAddr.address, { value: 10 });
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, deployer.address)).eq(10);
      await network.provider.send('evm_increaseTime', [cooldownSecsToUndelegate + 1]);
      await stakingContract.undelegate(poolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, deployer.address)).eq(9);
    });

    it('Should be not able to unstake with the balance left is not larger than the minimum balance threshold', async () => {
      await expect(
        stakingContract
          .connect(poolAddrSet.poolAdmin)
          .unstake(poolAddrSet.consensusAddr.address, minValidatorStakingAmount.add(1))
      ).revertedWithCustomError(stakingContract, 'ErrStakingAmountLeft');
    });

    it('Should not be able to request renounce using unauthorized account', async () => {
      await expect(
        stakingContract.connect(deployer).requestRenounce(poolAddrSet.consensusAddr.address)
      ).revertedWithCustomError(stakingContract, 'ErrOnlyPoolAdminAllowed');
    });

    it('Should the non-pool-admin not be able to update the commission rate', async () => {
      await expect(
        stakingContract.connect(poolAddrSet.bridgeOperator).requestUpdateCommissionRate(
          poolAddrSet.consensusAddr.address,
          minEffectiveDaysOnwards,
          20_00 // 20%
        )
      ).revertedWithCustomError(stakingContract, 'ErrOnlyPoolAdminAllowed');
    });

    it('Should the pool admin not be able to request updating the commission rate with invalid effective date', async () => {
      await expect(
        stakingContract.connect(poolAddrSet.poolAdmin).requestUpdateCommissionRate(
          poolAddrSet.consensusAddr.address,
          minEffectiveDaysOnwards - 1,
          20_00 // 20%
        )
      ).revertedWithCustomError(validatorContract, 'ErrInvalidEffectiveDaysOnwards');
    });

    it('Should the pool admin not be able to request updating the commission rate higher than max rate allowed', async () => {
      await expect(
        stakingContract.connect(poolAddrSet.poolAdmin).requestUpdateCommissionRate(
          poolAddrSet.consensusAddr.address,
          minEffectiveDaysOnwards - 1,
          maxCommissionRate + 1 // 20%
        )
      ).revertedWithCustomError(validatorContract, 'ErrInvalidCommissionRate');
    });
    it('Should the pool admin not be able to request updating the commission rate lower than min rate allowed', async () => {
      const minCommissionRate = 10_00;
      let data = stakingContract.interface.encodeFunctionData('setCommissionRateRange', [
        minCommissionRate,
        maxCommissionRate,
      ]);
      await proxyContract.connect(proxyAdmin).functionDelegateCall(data);

      await expect(
        stakingContract
          .connect(poolAddrSet.poolAdmin)
          .requestUpdateCommissionRate(
            poolAddrSet.consensusAddr.address,
            minEffectiveDaysOnwards,
            minCommissionRate - 1
          )
      ).revertedWithCustomError(stakingContract, 'ErrInvalidCommissionRate');
      data = stakingContract.interface.encodeFunctionData('setCommissionRateRange', [
        defaultMinCommissionRate,
        maxCommissionRate,
      ]);
      await proxyContract.connect(proxyAdmin).functionDelegateCall(data);
    });

    it('Should the pool admin not be able to request updating the commission rate exceeding max rate', async () => {
      await expect(
        stakingContract
          .connect(poolAddrSet.poolAdmin)
          .requestUpdateCommissionRate(
            poolAddrSet.consensusAddr.address,
            minEffectiveDaysOnwards,
            maxCommissionRate + 1
          )
      ).revertedWithCustomError(stakingContract, 'ErrInvalidCommissionRate');
    });

    it('Should the pool admin be able to request updating the commission rate', async () => {
      let _info = await validatorContract.getCandidateInfo(poolAddrSet.consensusAddr.address);
      let _previousRate = _info.commissionRate;

      let tx = stakingContract.connect(poolAddrSet.poolAdmin).requestUpdateCommissionRate(
        poolAddrSet.consensusAddr.address,
        minEffectiveDaysOnwards,
        20_00 // 20%
      );

      let lastBlockTimestamp = await getLastBlockTimestamp();
      let expectingEffectiveTime = (Math.floor(lastBlockTimestamp / ONE_DAY) + minEffectiveDaysOnwards) * ONE_DAY;

      await expect(tx)
        .emit(validatorContract, 'CommissionRateUpdateScheduled')
        .withArgs(poolAddrSet.consensusAddr.address, expectingEffectiveTime, 20_00);

      _info = await validatorContract.getCandidateInfo(poolAddrSet.consensusAddr.address);
      await expect(_info.commissionRate).eq(_previousRate);
    });

    it('Should the commission rate get updated when the waiting time passes', async () => {
      await network.provider.send('evm_increaseTime', [minEffectiveDaysOnwards * ONE_DAY]);
      let tx = await validatorContract.wrapUpEpoch();

      await expect(tx)
        .emit(validatorContract, 'CommissionRateUpdated')
        .withArgs(poolAddrSet.consensusAddr.address, 20_00);

      let _info = await validatorContract.getCandidateInfo(poolAddrSet.consensusAddr.address);
      await expect(_info.commissionRate).eq(20_00);
    });

    it('Should be able to request renounce using pool admin', async () => {
      await stakingContract.connect(poolAddrSet.poolAdmin).requestRenounce(poolAddrSet.consensusAddr.address);
    });

    it('Should not be able to request renounce again', async () => {
      await expect(
        stakingContract.connect(poolAddrSet.poolAdmin).requestRenounce(poolAddrSet.consensusAddr.address)
      ).revertedWithCustomError(validatorContract, 'ErrAlreadyRequestedRevokingCandidate');
    });

    it('Should the consensus account is no longer be a candidate, and the staked amount is transferred back to the pool admin', async () => {
      await network.provider.send('evm_increaseTime', [waitingSecsToRevoke]);
      const stakingAmount = minValidatorStakingAmount.mul(2);
      expect(await stakingContract.getPoolDetail(poolAddrSet.consensusAddr.address)).deep.equal([
        poolAddrSet.poolAdmin.address,
        stakingAmount,
        stakingAmount.add(9),
      ]);

      await expect(() => validatorContract.wrapUpEpoch()).changeEtherBalance(poolAddrSet.poolAdmin, stakingAmount);
      let _poolDetail = await stakingContract.getPoolDetail(poolAddrSet.consensusAddr.address);
      expect(_poolDetail._stakingAmount).eq(0);
    });

    it('Should the exited pool admin and consensus address rejoin as a candidate', async () => {
      const tx = await stakingContract
        .connect(poolAddrSet.poolAdmin)
        .applyValidatorCandidate(
          poolAddrSet.candidateAdmin.address,
          poolAddrSet.consensusAddr.address,
          poolAddrSet.treasuryAddr.address,
          1,
          /* 0.01% */ { value: minValidatorStakingAmount.mul(2) }
        );
      await expect(tx)
        .emit(stakingContract, 'PoolApproved')
        .withArgs(poolAddrSet.consensusAddr.address, poolAddrSet.poolAdmin.address);
      expect(
        await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, poolAddrSet.candidateAdmin.address)
      ).eq(minValidatorStakingAmount.mul(2));

      expect(await stakingContract.getStakingTotal(poolAddrSet.consensusAddr.address)).gte(
        minValidatorStakingAmount.mul(2)
      ); // previous delegated amount still exist
    });

    it('Should the a pool admin who is active cannot propose a new pool / cannot propose validator', async () => {
      await expect(
        stakingContract
          .connect(poolAddrSet.poolAdmin)
          .applyValidatorCandidate(
            poolAddrSet.candidateAdmin.address,
            poolAddrSet.consensusAddr.address,
            poolAddrSet.treasuryAddr.address,
            1,
            /* 0.01% */ { value: minValidatorStakingAmount.mul(2) }
          )
      )
        .revertedWithCustomError(stakingContract, 'ErrAdminOfAnyActivePoolForbidden')
        .withArgs(poolAddrSet.poolAdmin.address);

      await stakingContract.connect(poolAddrSet.poolAdmin).requestRenounce(poolAddrSet.consensusAddr.address);
      await network.provider.send('evm_increaseTime', [waitingSecsToRevoke]);
      await validatorContract.wrapUpEpoch();
    });
  });

  describe('Delegator test', () => {
    let increaseTimeOffset: number;
    before(() => {
      otherPoolAddrSet = validatorCandidates[1];
      anotherActivePoolSet = validatorCandidates[2];
    });

    it('Should be able to undelegate from a deprecated validator candidate', async () => {
      await stakingContract.undelegate(poolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, deployer.address)).eq(8);
    });

    it('Should not be able to delegate to a deprecated pool', async () => {
      await expect(stakingContract.delegate(poolAddrSet.consensusAddr.address, { value: 1 }))
        .revertedWithCustomError(stakingContract, 'ErrInactivePool')
        .withArgs(poolAddrSet.consensusAddr.address);
    });

    it('Should not be able to delegate with empty value', async () => {
      await expect(stakingContract.delegate(otherPoolAddrSet.consensusAddr.address)).revertedWithCustomError(
        stakingContract,
        'ErrZeroValue'
      );
    });

    it('Should not be able to delegate/undelegate when the method caller is the pool admin', async () => {
      await expect(
        stakingContract
          .connect(otherPoolAddrSet.poolAdmin)
          .delegate(otherPoolAddrSet.consensusAddr.address, { value: 1 })
      )
        .revertedWithCustomError(stakingContract, 'ErrAdminOfAnyActivePoolForbidden')
        .withArgs(otherPoolAddrSet.poolAdmin.address);

      await expect(
        stakingContract.connect(otherPoolAddrSet.poolAdmin).undelegate(otherPoolAddrSet.consensusAddr.address, 1)
      ).revertedWithCustomError(stakingContract, 'ErrPoolAdminForbidden');
    });

    it('Should not be able to delegate when the method caller is the admin of any arbitrary pool', async () => {
      await expect(
        stakingContract
          .connect(anotherActivePoolSet.poolAdmin)
          .delegate(otherPoolAddrSet.consensusAddr.address, { value: 1 })
      )
        .revertedWithCustomError(stakingContract, 'ErrAdminOfAnyActivePoolForbidden')
        .withArgs(anotherActivePoolSet.poolAdmin.address);

      await expect(
        stakingContract
          .connect(otherPoolAddrSet.poolAdmin)
          .delegate(anotherActivePoolSet.consensusAddr.address, { value: 1 })
      )
        .revertedWithCustomError(stakingContract, 'ErrAdminOfAnyActivePoolForbidden')
        .withArgs(otherPoolAddrSet.poolAdmin.address);
    });

    it('Should multiple accounts be able to delegate to one pool', async () => {
      let tx: ContractTransaction;
      tx = await stakingContract.connect(userA).delegate(otherPoolAddrSet.consensusAddr.address, { value: 1 });
      await expect(tx!)
        .emit(stakingContract, 'Delegated')
        .withArgs(userA.address, otherPoolAddrSet.consensusAddr.address, 1);

      tx = await stakingContract.connect(userB).delegate(otherPoolAddrSet.consensusAddr.address, { value: 1 });
      await expect(tx!)
        .emit(stakingContract, 'Delegated')
        .withArgs(userB.address, otherPoolAddrSet.consensusAddr.address, 1);

      expect(await stakingContract.getStakingTotal(otherPoolAddrSet.consensusAddr.address)).eq(
        minValidatorStakingAmount.mul(2).add(2)
      );
    });

    it('Should not be able to undelegate due to cooldown restriction', async () => {
      await expect(
        stakingContract.connect(userA).undelegate(otherPoolAddrSet.consensusAddr.address, 1)
      ).revertedWithCustomError(stakingContract, 'ErrUndelegateTooEarly');
    });

    it('Should be able to undelegate after cooldown', async () => {
      await network.provider.send('evm_increaseTime', [cooldownSecsToUndelegate + 1]);
      const tx = await stakingContract.connect(userA).undelegate(otherPoolAddrSet.consensusAddr.address, 1);
      await expect(tx!)
        .emit(stakingContract, 'Undelegated')
        .withArgs(userA.address, otherPoolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingTotal(otherPoolAddrSet.consensusAddr.address)).eq(
        minValidatorStakingAmount.mul(2).add(1)
      );
    });

    it('Should not be able to undelegate with empty amount', async () => {
      await expect(stakingContract.undelegate(otherPoolAddrSet.consensusAddr.address, 0)).revertedWithCustomError(
        stakingContract,
        'ErrUndelegateZeroAmount'
      );
    });

    it('Should not be able to undelegate more than the delegating amount', async () => {
      await expect(stakingContract.undelegate(otherPoolAddrSet.consensusAddr.address, 1000)).revertedWithCustomError(
        stakingContract,
        'ErrInsufficientDelegatingAmount'
      );
    });

    it('[Validator Candidate] Should an ex-candidate to rejoin Staking contract', async () => {
      await stakingContract
        .connect(poolAddrSet.poolAdmin)
        .applyValidatorCandidate(
          poolAddrSet.candidateAdmin.address,
          poolAddrSet.consensusAddr.address,
          poolAddrSet.treasuryAddr.address,
          2,
          /* 0.02% */ { value: minValidatorStakingAmount }
        );
      expect(await stakingContract.getPoolDetail(poolAddrSet.consensusAddr.address)).deep.equal([
        poolAddrSet.poolAdmin.address,
        minValidatorStakingAmount,
        minValidatorStakingAmount.add(8),
      ]);
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, deployer.address)).eq(8);
    });

    it('Should be able to delegate/undelegate for the rejoined candidate', async () => {
      await stakingContract.delegate(poolAddrSet.consensusAddr.address, { value: 2 });
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, deployer.address)).eq(10);

      await stakingContract.connect(userA).delegate(poolAddrSet.consensusAddr.address, { value: 2 });
      await stakingContract.connect(userB).delegate(poolAddrSet.consensusAddr.address, { value: 2 });
      expect(
        await stakingContract.getManyStakingAmounts(
          [poolAddrSet.consensusAddr.address, poolAddrSet.consensusAddr.address],
          [userA.address, userB.address]
        )
      ).deep.equal([2, 2].map(BigNumber.from));

      await network.provider.send('evm_increaseTime', [cooldownSecsToUndelegate + 1]);
      await stakingContract.connect(userA).undelegate(poolAddrSet.consensusAddr.address, 2);
      await stakingContract.connect(userB).undelegate(poolAddrSet.consensusAddr.address, 1);
      expect(
        await stakingContract.getManyStakingAmounts(
          [poolAddrSet.consensusAddr.address, poolAddrSet.consensusAddr.address],
          [userA.address, userB.address]
        )
      ).deep.equal([0, 1].map(BigNumber.from));
    });

    it('Should be able to delegate for a renouncing candidate', async () => {
      await stakingContract.connect(poolAddrSet.poolAdmin).requestRenounce(poolAddrSet.consensusAddr.address);
      await stakingContract.connect(userA).delegate(poolAddrSet.consensusAddr.address, { value: 2 });
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, userA.address)).eq(2);
    });

    it('Should be able to undelegate for a renouncing candidate without waiting for cooldown', async () => {
      let tx = await stakingContract.connect(userA).undelegate(poolAddrSet.consensusAddr.address, 1);
      await expect(tx).not.revertedWithCustomError(stakingContract, 'ErrUndelegateTooEarly');
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, userA.address)).eq(1);

      await network.provider.send('evm_increaseTime', [cooldownSecsToUndelegate + 1]);
      await stakingContract.connect(userA).undelegate(poolAddrSet.consensusAddr.address, 1);
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, userA.address)).eq(0);
    });

    it('Should be able to delegate for a renouncing candidate #2', async () => {
      increaseTimeOffset = 86400;
      await network.provider.send('evm_increaseTime', [
        waitingSecsToRevoke - (cooldownSecsToUndelegate + 1) - increaseTimeOffset,
      ]); // wrap up epoch before revoking time
      await validatorContract.wrapUpEpoch();
      expect(await validatorContract.isValidatorCandidate(poolAddrSet.consensusAddr.address)).eq(true);

      await stakingContract.connect(userB).delegate(poolAddrSet.consensusAddr.address, { value: 2 });
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, userB.address)).eq(3);
    });

    it('Should be able to undelegate for revoked candidate without waiting for cooldown', async () => {
      await network.provider.send('evm_increaseTime', [increaseTimeOffset]); // wrap up after before revoking time
      await validatorContract.wrapUpEpoch();
      expect(await validatorContract.isValidatorCandidate(poolAddrSet.consensusAddr.address)).eq(false);

      await stakingContract.connect(userB).undelegate(poolAddrSet.consensusAddr.address, 2);
      expect(await stakingContract.getStakingAmount(poolAddrSet.consensusAddr.address, userB.address)).eq(1);
    });
  });
});
