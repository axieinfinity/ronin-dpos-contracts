import { expect } from 'chai';
import { ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { Staking, Staking__factory } from '../../src/types';
import { ValidatorCandidateStruct } from '../../src/types/ValidatorSetCoreMock';
import { BigNumber } from 'ethers';

let stakingContract: Staking;

let signers: SignerWithAddress[];
let admin: SignerWithAddress;
let candidates: ValidatorCandidateStruct[];
let stakingAddrs: SignerWithAddress[];
let consensusAddrs: SignerWithAddress[];
let treasuryAddrs: SignerWithAddress[];

const generateCandidate = (
  stakingAddr: string,
  consensusAddr: string,
  treasuryAddr: string
): ValidatorCandidateStruct => {
  return {
    stakingAddr: stakingAddr,
    consensusAddr: consensusAddr,
    treasuryAddr: treasuryAddr,
    commissionRate: 0,
    stakedAmount: 0,
    delegatedAmount: 0,
    governing: false,
    ____gap: Array.apply(null, Array(20)).map((_) => 0),
  };
};

describe('Staking test', () => {
  let unstakingOnHoldBlocksNum: BigNumber;
  let minValidatorBalance: BigNumber;

  describe('Single flow', async () => {
    before(async () => {
      [admin, ...signers] = await ethers.getSigners();
      await deployments.fixture('StakingContract');
      const stakingProxyDeployment = await deployments.get('StakingProxy');
      stakingContract = Staking__factory.connect(stakingProxyDeployment.address, admin);

      candidates = [];
      stakingAddrs = [];
      consensusAddrs = [];
      treasuryAddrs = [];

      unstakingOnHoldBlocksNum = await stakingContract.unstakingOnHoldBlocksNum();
      minValidatorBalance = await stakingContract.minValidatorBalance();

      console.log('Set validator set contract...');
      await stakingContract.setValidatorSetContract(admin.address);

      console.log('Init addresses...');
      for (let i = 0; i < 10; i++) {
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

    describe('Validator functions', async () => {
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
          expect(await stakingContract.getPendingRenoucingValidatorIndexes()).to.eql([BigNumber.from(1)]);
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

          expect(await stakingContract.getPendingRenoucingValidatorIndexes()).to.eql([]);
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
      });

      describe('Propose and renounce multiple validator', async () => {
        // TODO:
      });
    });

    describe('Delegator functions', async () => {});

    describe('Updating validator functions', async () => {});
  });
});
