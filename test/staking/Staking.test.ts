import { expect } from 'chai';
import { ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { Staking, Staking__factory } from '../../src/types';
import { ValidatorCandidateStruct } from '../../src/types/IStaking';
import { BigNumber } from 'ethers';
import { DEFAULT_ADDRESS } from '../../src/utils';

let stakingContract: Staking;

let signers: SignerWithAddress[];
let admin: SignerWithAddress;
let candidates: ValidatorCandidateStruct[] = [];
let stakingAddrs: SignerWithAddress[] = [];
let consensusAddrs: SignerWithAddress[] = [];
let treasuryAddrs: SignerWithAddress[] = [];

enum ValidatorStateEnum {
  ACTIVE = 0,
  ON_REQUESTING_RENOUNCE = 1,
  ON_CONFIRMED_RENOUNCE = 2,
  RENOUNCED = 3,
}

const generateCandidate = (
  candidateAdmin: string,
  consensusAddr: string,
  treasuryAddr: string
): ValidatorCandidateStruct => {
  return {
    candidateAdmin: candidateAdmin,
    consensusAddr: consensusAddr,
    treasuryAddr: treasuryAddr,
    commissionRate: 0,
    stakedAmount: 0,
    state: ValidatorStateEnum.ACTIVE,
    delegatedAmount: 0,
    governing: false,
    ____gap: Array.apply(null, Array(20)).map((_) => 0),
  };
};

const validateTwoObjects = async (definedObj: any, resultObj: any) => {
  let key: keyof typeof definedObj;
  for (key in definedObj) {
    const definedVal = definedObj[key];
    const resultVal = resultObj[key];

    if (Array.isArray(resultVal)) {
      for (let i = 0; i < resultVal.length; i++) {
        await expect(resultVal[i]).to.eq(definedVal[i]);
      }
    } else {
      await expect(resultVal).to.eq(definedVal);
    }
  }
};

describe('Staking test', () => {
  let unstakingOnHoldBlocksNum: BigNumber;
  let minValidatorBalance: BigNumber;

  before(async () => {
    [admin, ...signers] = await ethers.getSigners();

    console.log('Init addresses for 21 candidates...');
    for (let i = 0; i < 21; i++) {
      candidates.push(
        generateCandidate(signers[3 * i].address, signers[3 * i + 1].address, signers[3 * i + 2].address)
      );
      stakingAddrs.push(signers[3 * i]);
      consensusAddrs.push(signers[3 * i + 1]);
      treasuryAddrs.push(signers[3 * i + 2]);

      console.log(
        i,
        signers[3 * i].address,
        signers[3 * i + 1].address,
        signers[3 * i + 2].address,
        (await ethers.provider.getBalance(signers[3 * i].address)).toString(),
        (await ethers.provider.getBalance(signers[3 * i + 1].address)).toString(),
        (await ethers.provider.getBalance(signers[3 * i + 2].address)).toString()
      );
    }
  });

  describe('Single flow', async () => {
    describe('Validator functions', async () => {
      before(async () => {
        await deployments.fixture('StakingContract');
        const stakingProxyDeployment = await deployments.get('StakingProxy');
        stakingContract = Staking__factory.connect(stakingProxyDeployment.address, admin);

        unstakingOnHoldBlocksNum = await stakingContract.unstakingOnHoldBlocksNum();
        minValidatorBalance = await stakingContract.minValidatorBalance();

        console.log('Set validator set contract...');
        await stakingContract.setValidatorSetContract(admin.address);
      });

      describe('Proposing', async () => {
        it('Should be able to propose 1 validator', async () => {
          let tx = await stakingContract
            .connect(stakingAddrs[0])
            .proposeValidator(consensusAddrs[0].address, treasuryAddrs[0].address, 0, {
              value: minValidatorBalance.toString(),
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[0].address, stakingAddrs[0].address, minValidatorBalance, candidates[0]);
        });

        it('Should not be able to propose 1 validator - insufficient fund', async () => {
          let tx = stakingContract
            .connect(stakingAddrs[1])
            .proposeValidator(consensusAddrs[1].address, treasuryAddrs[1].address, 0, {
              value: minValidatorBalance.sub(1).toString(),
            });
          await expect(tx).to.revertedWith('Staking: insuficient amount');
        });

        it('Should not be able to propose 1 validator - duplicated validator', async () => {
          let tx = stakingContract
            .connect(stakingAddrs[0])
            .proposeValidator(consensusAddrs[0].address, treasuryAddrs[0].address, 0, {
              value: minValidatorBalance.toString(),
            });
          await expect(tx).to.revertedWith('Staking: cannot propose an existed candidate');
        });
      });

      describe('Staking', async () => {
        it('Should be able to stake for a validator', async () => {
          let stakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[0]).stake(consensusAddrs[0].address, {
            value: stakingValue,
          });
          await expect(tx).to.emit(stakingContract, 'Staked').withArgs(consensusAddrs[0].address, stakingValue);
        });

        it('Should not be able to stake for an unexistent validator', async () => {
          let stakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[0]).stake(consensusAddrs[1].address, {
            value: stakingValue,
          });
          await expect(tx).to.revertedWith('Staking: query for nonexistent candidate');
        });
      });

      describe('Unstaking', async () => {
        it('Should not be able to unstake - exceeds minimum balance', async () => {
          let unstakingValue = ethers.utils.parseEther('1.1');
          let tx = stakingContract.connect(stakingAddrs[0]).unstake(consensusAddrs[0].address, unstakingValue);
          await expect(tx).to.revertedWith('Staking: invalid staked amount left');
        });

        it('Should not be able to unstake - caller is not staking address', async () => {
          let unstakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[1]).unstake(consensusAddrs[0].address, unstakingValue);
          await expect(tx).to.revertedWith('Staking: caller must be staking address');
        });

        it('Should be able to unstake', async () => {
          let tx;
          let unstakingValue = ethers.utils.parseEther('1.0');
          let descresingValue = ethers.utils.parseEther('-1.0');
          await expect(
            () => (tx = stakingContract.connect(stakingAddrs[0]).unstake(consensusAddrs[0].address, unstakingValue))
          ).to.changeEtherBalances([stakingAddrs[0], stakingContract], [unstakingValue, descresingValue]);
          await expect(tx).to.emit(stakingContract, 'Unstaked').withArgs(consensusAddrs[0].address, unstakingValue);
        });

        it('Should not be able to unstake - exceeds minimum balance 2', async () => {
          let unstakingValue = 1;
          let tx = stakingContract.connect(stakingAddrs[0]).unstake(consensusAddrs[0].address, unstakingValue);
          await expect(tx).to.revertedWith('Staking: invalid staked amount left');
        });
      });

      describe('Requesting renounce', async () => {
        it('Should not be able to request renounce validator - caller is not staking address', async () => {
          let tx = stakingContract.connect(stakingAddrs[1]).requestRenouncingValidator(consensusAddrs[0].address);
          await expect(tx).to.revertedWith('Staking: caller must be staking address');
        });

        it('Should be able to request renounce validator', async () => {
          let stakingValue = ethers.utils.parseEther('1.0');
          await stakingContract.connect(stakingAddrs[0]).stake(consensusAddrs[0].address, {
            value: stakingValue,
          });

          let tx = stakingContract.connect(stakingAddrs[0]).requestRenouncingValidator(consensusAddrs[0].address);
          await expect(tx)
            .to.emit(stakingContract, 'ValidatorRenounceRequested')
            .withArgs(consensusAddrs[0].address, minValidatorBalance.add(stakingValue));
        });

        it('Should not be able to request renounce validator twice', async () => {
          let tx = stakingContract.connect(stakingAddrs[0]).requestRenouncingValidator(consensusAddrs[0].address);
          await expect(tx).to.revertedWith('Staking: query for deprecated candidate');
        });

        it('Should not be able to propose the validator that is on renounce', async () => {
          let tx = stakingContract
            .connect(stakingAddrs[0])
            .proposeValidator(consensusAddrs[0].address, treasuryAddrs[0].address, 0, {
              value: minValidatorBalance.toString(),
            });
          await expect(tx).to.revertedWith('Staking: cannot propose an existed candidate');
        });

        it('Should not be able to stake for the validator that is on renounce', async () => {
          let stakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[0]).stake(consensusAddrs[0].address, {
            value: stakingValue,
          });

          await expect(tx).to.revertedWith('Staking: query for deprecated candidate');
        });

        it('Should not be able to unstake for the validator that is on renounce', async () => {
          let unstakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[1]).unstake(consensusAddrs[0].address, unstakingValue);
          await expect(tx).to.revertedWith('Staking: query for deprecated candidate');
        });
      });

      describe('Finalize renounce', async () => {
        it('Should not be able to finalize the renounce - caller is not staking address', async () => {
          let tx = stakingContract.connect(stakingAddrs[1]).finalizeRenouncingValidator(consensusAddrs[0].address);
          await expect(tx).to.revertedWith('Staking: caller must be staking address');
        });

        it('Should not be able to finalize renounce - renounce is not confirmed', async () => {
          let tx = stakingContract.connect(stakingAddrs[0]).finalizeRenouncingValidator(consensusAddrs[0].address);
          await expect(tx).to.revertedWith('Staking: validator state is not ON_CONFIRMED_RENOUNCE');
        });

        it('Should be able to finalize the renounce', async () => {
          expect(await stakingContract.getPendingRenouncingValidatorIndexes()).to.eql([BigNumber.from(1)]);
          await stakingContract.connect(admin).updateValidatorSet();

          let tx;
          let incValue = minValidatorBalance.add(ethers.utils.parseEther('1'));
          let decValue = BigNumber.from(0).sub(incValue);
          await expect(
            () => (tx = stakingContract.connect(stakingAddrs[0]).finalizeRenouncingValidator(consensusAddrs[0].address))
          ).to.changeEtherBalances([stakingAddrs[0], stakingContract], [incValue, decValue]);
          await expect(tx)
            .to.emit(stakingContract, 'ValidatorRenounceFinalized')
            .withArgs(consensusAddrs[0].address, incValue);

          expect(await stakingContract.getPendingRenouncingValidatorIndexes()).to.eql([]);
        });

        it('Should not be able to finalize renounce twice', async () => {
          let tx = stakingContract.connect(stakingAddrs[0]).finalizeRenouncingValidator(consensusAddrs[0].address);
          await expect(tx).to.revertedWith('Staking: validator state is not ON_CONFIRMED_RENOUNCE');
        });

        it('Should not be able to stake for a renounced validator', async () => {
          let stakingValue = ethers.utils.parseEther('1.0');
          let tx = stakingContract.connect(stakingAddrs[0]).stake(consensusAddrs[0].address, {
            value: stakingValue,
          });
          await expect(tx).to.revertedWith('Staking: query for deprecated candidate');
        });

        it('Should be able to re-propose the renounced validator, the old index unchanges', async () => {
          let tx = await stakingContract
            .connect(stakingAddrs[0])
            .proposeValidator(consensusAddrs[0].address, treasuryAddrs[0].address, 0, {
              value: minValidatorBalance.toString(),
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[0].address, stakingAddrs[0].address, minValidatorBalance, candidates[0]);

          let _expectingCandidate = {
            candidateAdmin: stakingAddrs[0].address,
            consensusAddr: consensusAddrs[0].address,
            treasuryAddr: treasuryAddrs[0].address,
            commissionRate: 0,
            stakedAmount: minValidatorBalance,
            state: ValidatorStateEnum.ACTIVE,
            delegatedAmount: 0,
            governing: false,
          };
          await validateTwoObjects(_expectingCandidate, await stakingContract.validatorCandidates(1));
        });
      });

      describe('Propose and renounce multiple validator', async () => {
        it('Should be able to propose 5 more validator', async () => {
          // balance: [3M, 3M+1, 3M+2, 3M+3, 3M+4, 3M+5]
          for (let i = 1; i <= 5; ++i) {
            let topupValue = minValidatorBalance.add(ethers.utils.parseEther(i.toString()));
            let tx = await stakingContract
              .connect(stakingAddrs[i])
              .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
                value: topupValue,
              });
            expect(await tx)
              .to.emit(stakingContract, 'ValidatorProposed')
              .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
          }

          await stakingContract.connect(admin).updateValidatorSet();
          let currentSet = await stakingContract.getCurrentValidatorSet();
          let expectingSet = [DEFAULT_ADDRESS].concat([5, 4, 3, 2, 1, 0].map((i) => consensusAddrs[i].address));
          console.log('>>> currentSet', currentSet);
          await expect(expectingSet).eql(currentSet);
        });

        describe('Renounce 2 in 6 validator', async () => {
          it('Should request to renounce success', async () => {
            for (let i = 3; i <= 4; ++i) {
              let topoutValue = minValidatorBalance.add(ethers.utils.parseEther(i.toString()));
              let tx = stakingContract.connect(stakingAddrs[i]).requestRenouncingValidator(consensusAddrs[i].address);
              await expect(tx)
                .to.emit(stakingContract, 'ValidatorRenounceRequested')
                .withArgs(consensusAddrs[i].address, topoutValue);
            }
          });

          it('Should pending list get updated correctly', async () => {
            expect(await stakingContract.getPendingRenouncingValidatorIndexes()).to.eql([
              BigNumber.from(4),
              BigNumber.from(5),
            ]);
          });

          it('Should be update validators list success', async () => {
            await stakingContract.connect(admin).updateValidatorSet();
            let currentSet = await stakingContract.getCurrentValidatorSet();
            let expectingSet = [DEFAULT_ADDRESS].concat([5, 2, 1, 0].map((i) => consensusAddrs[i].address));
            console.log('>>> currentSet', currentSet);
            await expect(expectingSet).eql(currentSet);
          });
        });
      });
    });

    describe('Delegator functions', async () => {});

    describe('Updating validator functions', async () => {
      beforeEach(async () => {
        await deployments.fixture('StakingContract');
        const stakingProxyDeployment = await deployments.get('StakingProxy');
        stakingContract = Staking__factory.connect(stakingProxyDeployment.address, admin);

        unstakingOnHoldBlocksNum = await stakingContract.unstakingOnHoldBlocksNum();
        minValidatorBalance = await stakingContract.minValidatorBalance();

        console.log('Set validator set contract...');
        await stakingContract.setValidatorSetContract(admin.address);
      });

      it('Should sort 21 validator in descreasing order', async () => {
        // balance: [3M+20, 3M+19, 3M+18, 3M+17, 3M+16, 3M+15, ...]
        for (let i = 0; i < 21; ++i) {
          let topupValue = minValidatorBalance.add(ethers.utils.parseEther((20 - i).toString()));
          let tx = await stakingContract
            .connect(stakingAddrs[i])
            .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
              value: topupValue,
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
        }

        await stakingContract.connect(admin).updateValidatorSet();
        let currentSet = await stakingContract.getCurrentValidatorSet();
        let expectingSet = [DEFAULT_ADDRESS].concat([...Array(21).keys()].map((i) => consensusAddrs[i].address));
        console.log('>>> currentSet', currentSet);
        await expect(expectingSet).eql(currentSet);
      });

      it('Should sort 21 validator in increasing order', async () => {
        // balance: [3M, 3M+1, 3M+2, 3M+3, 3M+4, 3M+5, ...]
        for (let i = 0; i < 21; ++i) {
          let topupValue = minValidatorBalance.add(ethers.utils.parseEther(i.toString()));
          let tx = await stakingContract
            .connect(stakingAddrs[i])
            .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
              value: topupValue,
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
        }

        await stakingContract.connect(admin).updateValidatorSet();
        let currentSet = await stakingContract.getCurrentValidatorSet();
        let expectingSet = [DEFAULT_ADDRESS].concat(
          Array.from({ length: 21 }, (_, j) => 20 - j).map((i) => consensusAddrs[i].address)
        );
        console.log('>>> currentSet', currentSet);
        await expect(expectingSet).eql(currentSet);
      });

      it('Should sort 21 validator in mixed order', async () => {
        let balances = [];
        for (let i = 0; i < 21; ++i) {
          balances.push({
            key: i,
            value: Math.floor(Math.random() * 1000),
          });
        }

        for (let j = 0; j < 21; ++j) {
          let i = balances[j].key;
          let topupValue = minValidatorBalance.add(ethers.utils.parseEther(balances[j].value.toString()));
          let tx = await stakingContract
            .connect(stakingAddrs[i])
            .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
              value: topupValue,
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
        }

        balances.sort((a, b) => (a.value < b.value ? 1 : a.value == b.value ? (a.key < b.key ? 1 : -1) : -1));
        console.log(
          '>>> balances index after sort',
          balances.map((e) => e.key + 1)
        );

        await stakingContract.connect(admin).updateValidatorSet();
        let currentSet = await stakingContract.getCurrentValidatorSet();
        let expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        console.log('>>> currentSet', currentSet);
        await expect(expectingSet).eql(currentSet);
      });

      it('Should ignore the second sort for 21 validator', async () => {
        let balances = [];
        for (let i = 0; i < 21; ++i) {
          balances.push({
            key: i,
            value: Math.floor(Math.random() * 1000),
          });
        }

        for (let j = 0; j < 21; ++j) {
          let i = balances[j].key;
          let topupValue = minValidatorBalance.add(ethers.utils.parseEther(balances[j].value.toString()));
          let tx = await stakingContract
            .connect(stakingAddrs[i])
            .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
              value: topupValue,
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
        }

        balances.sort((a, b) => (a.value < b.value ? 1 : a.value == b.value ? (a.key < b.key ? 1 : -1) : -1));
        console.log(
          '>>> balances index after sort',
          balances.map((e) => e.key + 1)
        );

        // first sort
        await stakingContract.connect(admin).updateValidatorSet();
        let currentSet = await stakingContract.getCurrentValidatorSet();
        let expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        await expect(expectingSet).eql(currentSet);

        // second sort
        await stakingContract.connect(admin).updateValidatorSet();
        currentSet = await stakingContract.getCurrentValidatorSet();
        expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        await expect(expectingSet).eql(currentSet);
      });

      it('Should ignore the second and third sort for 21 validator', async () => {
        let balances = [];
        for (let i = 0; i < 21; ++i) {
          balances.push({
            key: i,
            value: Math.floor(Math.random() * 1000),
          });
        }

        for (let j = 0; j < 21; ++j) {
          let i = balances[j].key;
          let topupValue = minValidatorBalance.add(ethers.utils.parseEther(balances[j].value.toString()));
          let tx = await stakingContract
            .connect(stakingAddrs[i])
            .proposeValidator(consensusAddrs[i].address, treasuryAddrs[i].address, i * 100, {
              value: topupValue,
            });
          expect(await tx)
            .to.emit(stakingContract, 'ValidatorProposed')
            .withArgs(consensusAddrs[i].address, stakingAddrs[i].address, topupValue, candidates[i]);
        }

        balances.sort((a, b) => (a.value < b.value ? 1 : a.value == b.value ? (a.key < b.key ? 1 : -1) : -1));
        console.log(
          '>>> balances index after sort',
          balances.map((e) => e.key + 1)
        );

        // first sort
        await stakingContract.connect(admin).updateValidatorSet();
        let currentSet = await stakingContract.getCurrentValidatorSet();
        let expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        await expect(expectingSet).eql(currentSet);

        // second sort
        await stakingContract.connect(admin).updateValidatorSet();
        currentSet = await stakingContract.getCurrentValidatorSet();
        expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        await expect(expectingSet).eql(currentSet);

        // third sort
        await stakingContract.connect(admin).updateValidatorSet();
        currentSet = await stakingContract.getCurrentValidatorSet();
        expectingSet = [DEFAULT_ADDRESS].concat(balances.map((e) => consensusAddrs[e.key].address));
        await expect(expectingSet).eql(currentSet);
      });
    });
  });
});
