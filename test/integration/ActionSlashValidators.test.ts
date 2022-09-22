import { expect } from 'chai';
import { network, ethers, deployments, getNamedAccounts } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Address } from 'hardhat-deploy/dist/types';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetExtends__factory,
  MockRoninValidatorSetExtends,
  ProxyAdmin__factory,
} from '../../src/types';
import {
  Network,
  slashIndicatorConf,
  roninValidatorSetConf,
  stakingConfig,
  stakingVestingConfig,
  initAddress,
  scheduledMaintenanceConfig,
} from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { expects as RoninValidatorSetExpects } from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';
import { SlashType } from '../../src/script/slash-indicator';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtends;

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;

const maxValidatorNumber = 3;
const maxPrioritizedValidatorNumber = 0;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;

const minValidatorBalance = BigNumber.from(100);
const maxValidatorCandidate = 10;

const bonusPerBlock = BigNumber.from(1);
const topUpAmount = BigNumber.from(10000);

const minMaintenanceBlockPeriod = 100;
const maxMaintenanceBlockPeriod = 1000;
const minOffset = 200;
const maxSchedules = 2;

describe('[Integration] Slash validators', () => {
  before(async () => {
    [deployer, coinbase, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    if (network.name == Network.Hardhat) {
      initAddress[network.name] = {
        governanceAdmin: governanceAdmin.address,
      };
      scheduledMaintenanceConfig[network.name] = {
        minMaintenanceBlockPeriod,
        maxMaintenanceBlockPeriod,
        minOffset,
        maxSchedules,
      };
      slashIndicatorConf[network.name] = {
        misdemeanorThreshold: misdemeanorThreshold,
        felonyThreshold: felonyThreshold,
        slashFelonyAmount: slashFelonyAmount,
        slashDoubleSignAmount: slashDoubleSignAmount,
        felonyJailBlocks: felonyJailDuration,
      };
      roninValidatorSetConf[network.name] = {
        maxValidatorNumber: maxValidatorNumber,
        maxValidatorCandidate: maxValidatorCandidate,
        maxPrioritizedValidatorNumber: maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch: numberOfBlocksInEpoch,
        numberOfEpochsInPeriod: numberOfEpochsInPeriod,
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
      };
      stakingVestingConfig[network.name] = {
        bonusPerBlock: bonusPerBlock,
        topupAmount: topUpAmount,
      };
    }

    await deployments.fixture([
      'ProxyAdmin',
      'CalculateAddresses',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'StakingVestingProxy',
    ]);

    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    slashContract = SlashIndicator__factory.connect(slashContractDeployment.address, deployer);

    const stakingContractDeployment = await deployments.get('StakingProxy');
    stakingContract = Staking__factory.connect(stakingContractDeployment.address, deployer);

    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');
    validatorContract = MockRoninValidatorSetExtends__factory.connect(validatorContractDeployment.address, deployer);

    const mockValidatorLogic = await new MockRoninValidatorSetExtends__factory(deployer).deploy();
    await mockValidatorLogic.deployed();

    const proxyAdminDeployment = await deployments.get('ProxyAdmin');
    let proxyAdminContract = ProxyAdmin__factory.connect(proxyAdminDeployment.address, deployer);

    await proxyAdminContract.upgrade(validatorContract.address, mockValidatorLogic.address);
  });

  describe('Configuration test', async () => {
    describe('ValidatorSetContract configuration', async () => {
      it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
        let _stakingContract = await validatorContract.stakingContract();
        expect(_stakingContract).to.eq(stakingContract.address);
      });

      it('Should the ValidatorSetContract config the Slashing correctly', async () => {
        let _slashingContract = await validatorContract.slashIndicatorContract();
        expect(_slashingContract).to.eq(slashContract.address);
      });
    });

    describe('StakingContract configuration', async () => {
      it('Should the StakingContract config the ValidatorSetContract correctly', async () => {
        let _validatorSetContract = await stakingContract.validatorContract();
        expect(_validatorSetContract).to.eq(validatorContract.address);
      });
    });

    describe('SlashIndicatorContract configuration', async () => {
      it('Should the SlashIndicatorContract config the ValidatorSetContract correctly', async () => {
        let _validatorSetContract = await slashContract.validatorContract();
        expect(_validatorSetContract).to.eq(validatorContract.address);
      });
    });
  });

  describe('Slash one validator', async () => {
    let expectingValidatorSet: Address[] = [];

    describe('Slash misdemeanor validator', async () => {
      it('Should the ValidatorSet contract emit event', async () => {
        let slasheeIdx = 1;
        let slashee = validatorCandidates[slasheeIdx];

        for (let i = 0; i < misdemeanorThreshold - 1; i++) {
          await slashContract.connect(coinbase).slash(slashee.address);
        }
        let tx = slashContract.connect(coinbase).slash(slashee.address);

        await expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(slashee.address, SlashType.MISDEMEANOR);
        await expect(tx).to.emit(validatorContract, 'ValidatorSlashed').withArgs(slashee.address, 0, 0);
      });
    });

    describe('Slash felony validator -- when the validators balance is sufficient after being slashed', async () => {
      let updateValidatorTx: ContractTransaction;
      let slashValidatorTx: ContractTransaction;
      let slasheeIdx: number;
      let slashee: SignerWithAddress;
      let slasheeInitStakingAmount: BigNumber;

      before(async () => {
        slasheeIdx = 2;
        slashee = validatorCandidates[slasheeIdx];
        slasheeInitStakingAmount = minValidatorBalance.add(slashFelonyAmount.mul(10));
        await stakingContract
          .connect(slashee)
          .proposeValidator(slashee.address, slashee.address, slashee.address, 2_00, {
            value: slasheeInitStakingAmount,
          });

        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(slasheeInitStakingAmount);

        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        expectingValidatorSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);

        expect(await validatorContract.getValidators()).eql(expectingValidatorSet);
      });

      it('Should the ValidatorSet contract emit event', async () => {
        for (let i = 0; i < felonyThreshold - 1; i++) {
          await slashContract.connect(coinbase).slash(slashee.address);
        }
        slashValidatorTx = await slashContract.connect(coinbase).slash(slashee.address);

        await expect(slashValidatorTx)
          .to.emit(slashContract, 'ValidatorSlashed')
          .withArgs(slashee.address, SlashType.FELONY);

        let blockNumber = await network.provider.send('eth_blockNumber');

        await expect(slashValidatorTx)
          .to.emit(validatorContract, 'ValidatorSlashed')
          .withArgs(slashee.address, BigNumber.from(blockNumber).add(felonyJailDuration), slashFelonyAmount);
      });

      it('Should the validator is put in jail', async () => {
        let blockNumber = await network.provider.send('eth_blockNumber');
        expect(await validatorContract.getJailUntils(expectingValidatorSet)).eql([
          BigNumber.from(blockNumber).add(felonyJailDuration),
        ]);
      });

      it('Should the Staking contract emit Unstaked event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Unstaked')
          .withArgs(slashee.address, slashFelonyAmount);
      });

      it('Should the Staking contract emit Undelegated event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Undelegated')
          .withArgs(slashee.address, slashee.address, slashFelonyAmount);
      });

      it('Should the Staking contract subtract staked amount from validator', async () => {
        let _expectingSlasheeStakingAmount = slasheeInitStakingAmount.sub(slashFelonyAmount);
        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(_expectingSlasheeStakingAmount);
      });

      it('Should the validator set exclude the jailed validator in the next epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingValidatorSet.pop();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });

      it('Should the validator candidate cannot re-join as a validator when jail time is not over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, []);
      });

      it('Should the validator candidate re-join as a validator when jail time is over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingValidatorSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });
    });

    describe('Slash felony validator -- when the validators balance is equal to minimum balance', async () => {
      let updateValidatorTx: ContractTransaction;
      let slashValidatorTx: ContractTransaction;
      let slasheeIdx: number;
      let slashee: SignerWithAddress;
      let slasheeInitStakingAmount: BigNumber;

      before(async () => {
        slasheeIdx = 3;
        slashee = validatorCandidates[slasheeIdx];
        slasheeInitStakingAmount = minValidatorBalance;

        await stakingContract
          .connect(slashee)
          .proposeValidator(slashee.address, slashee.address, slashee.address, 2_00, {
            value: slasheeInitStakingAmount,
          });

        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(slasheeInitStakingAmount);

        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingValidatorSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);

        expect(await validatorContract.getValidators()).eql(expectingValidatorSet);
      });

      it('Should the ValidatorSet contract emit event', async () => {
        for (let i = 0; i < felonyThreshold - 1; i++) {
          await slashContract.connect(coinbase).slash(slashee.address);
        }
        slashValidatorTx = await slashContract.connect(coinbase).slash(slashee.address);

        await expect(slashValidatorTx)
          .to.emit(slashContract, 'ValidatorSlashed')
          .withArgs(slashee.address, SlashType.FELONY);

        let blockNumber = await network.provider.send('eth_blockNumber');

        await expect(slashValidatorTx)
          .to.emit(validatorContract, 'ValidatorSlashed')
          .withArgs(slashee.address, BigNumber.from(blockNumber).add(felonyJailDuration), slashFelonyAmount);
      });

      it('Should the validator is put in jail', async () => {
        let blockNumber = await network.provider.send('eth_blockNumber');
        expect(await validatorContract.getJailUntils([slashee.address])).eql([
          BigNumber.from(blockNumber).add(felonyJailDuration),
        ]);
      });

      it('Should the Staking contract emit Unstaked event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Unstaked')
          .withArgs(slashee.address, slashFelonyAmount);
      });

      it('Should the Staking contract emit Undelegated event', async () => {
        await expect(slashValidatorTx)
          .to.emit(stakingContract, 'Undelegated')
          .withArgs(slashee.address, slashee.address, slashFelonyAmount);
      });

      it('Should the Staking contract subtract staked amount from validator', async () => {
        let _expectingSlasheeStakingAmount = slasheeInitStakingAmount.sub(slashFelonyAmount);
        expect(await stakingContract.balanceOf(slashee.address, slashee.address)).eq(_expectingSlasheeStakingAmount);
      });

      it('Should the validator set exclude the jailed validator in the next epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingValidatorSet.pop();
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });

      it('Should the validator candidate cannot re-join as a validator when jail time is not over', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber).sub(100);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });

        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });

      it('Should the validator candidate cannot join as a validator when jail time is over, due to insufficient fund', async () => {
        let _blockNumber = await network.provider.send('eth_blockNumber');
        let _jailUntil = await validatorContract.getJailUntils([slashee.address]);
        let _numOfBlockToEndJailTime = _jailUntil[0].sub(_blockNumber);

        await network.provider.send('hardhat_mine', [_numOfBlockToEndJailTime.toHexString()]);
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });

      it('Should the validator top-up balance for being sufficient minimum balance of a validator', async () => {
        let topUpTx = await stakingContract.connect(slashee).stake(slashee.address, {
          value: slashFelonyAmount,
        });

        await expect(topUpTx).to.emit(stakingContract, 'Staked').withArgs(slashee.address, slashFelonyAmount);
        await expect(topUpTx)
          .to.emit(stakingContract, 'Delegated')
          .withArgs(slashee.address, slashee.address, slashFelonyAmount);
      });

      // NOTE: the candidate is kicked right after the epoch is ended.
      it.skip('Should the validator be able to re-join the validator set', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.connect(coinbase).endEpoch();
          updateValidatorTx = await validatorContract.connect(coinbase).wrapUpEpoch();
        });
        expectingValidatorSet.push(slashee.address);
        await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, expectingValidatorSet);
      });
    });
  });

  // TODO(Bao): Test for reward amount of validators and delegators
});
