import { expect } from 'chai';
import { network, ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

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
  initAddress,
  stakingVestingConfig,
  MaintenanceConfig,
} from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { expects as StakingExpects } from '../helpers/reward-calculation';
import { expects as ValidatorSetExpects } from '../helpers/ronin-validator-set';
import { mineBatchTxs } from '../helpers/utils';

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

describe('[Integration] Wrap up epoch', () => {
  const blockRewardAmount = BigNumber.from(2);

  before(async () => {
    [deployer, coinbase, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    if (network.name == Network.Hardhat) {
      initAddress[network.name] = {
        governanceAdmin: governanceAdmin.address,
      };
      MaintenanceConfig[network.name] = {
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

  describe('Configuration test', () => {
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

  describe('Flow test on one validator', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: SignerWithAddress[];

    before(async () => {
      validators = validatorCandidates.slice(0, 4);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validatorCandidates[i])
          .proposeValidator(
            validatorCandidates[i].address,
            validatorCandidates[i].address,
            validatorCandidates[i].address,
            2_00,
            {
              value: minValidatorBalance.mul(2).add(i),
            }
          );
      }

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      await network.provider.send('hardhat_setCoinbase', [validators[3].address]);
      validatorContract = validatorContract.connect(validators[3]);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    after(async () => {
      coinbase = validators[3];
    });

    describe('Wrap up epoch: at the end of the epoch', async () => {
      it('Should validator not be able to wrap up the epoch twice, in the same epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
          let duplicatedWrapUpTx = validatorContract.wrapUpEpoch();

          await expect(duplicatedWrapUpTx).to.be.revertedWith('RoninValidatorSet: query for already wrapped up epoch');
        });
      });

      it('Should validator be able to wrap up the epoch', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
      });

      describe.skip('ValidatorSetContract internal actions', async () => {});

      describe('StakingContract internal actions: settle reward pool', async () => {
        it('Should the StakingContract emit event of settling reward', async () => {
          await StakingExpects.emitSettledPoolsUpdatedEvent(
            wrapUpTx,
            validators
              .slice(1, 4)
              .map((_) => _.address)
              .reverse()
          );
        });
      });
    });

    describe('Wrap up epoch: at the end of the period', async () => {
      it('Should the ValidatorSet not reset counter, when the period is not ended', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        // TODO: slash someone here and check the slash indicator
      });

      it('Should the ValidatorSet reset counter in SlashIndicator contract', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        // TODO: slash someone here and check the slash indicator
      });
    });
  });

  describe('Flow test on many validators', async () => {
    let wrapUpTx: ContractTransaction;
    let validators: SignerWithAddress[];

    before(async () => {
      validators = validatorCandidates.slice(4, 8);

      for (let i = 0; i < validators.length; i++) {
        await stakingContract
          .connect(validators[i])
          .proposeValidator(validators[i].address, validators[i].address, validators[i].address, 2_00, {
            value: minValidatorBalance.mul(3).add(i),
          });
      }

      await mineBatchTxs(async () => {
        await validatorContract.connect(coinbase).endEpoch();
        await validatorContract.connect(coinbase).wrapUpEpoch();
      });

      await network.provider.send('hardhat_setCoinbase', [validators[3].address]);
      validatorContract = validatorContract.connect(validators[3]);
      await validatorContract.submitBlockReward({
        value: blockRewardAmount,
      });
    });

    describe('One validator get slashed between period', async () => {
      before(async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.wrapUpEpoch();
        });

        for (let i = 0; i < felonyThreshold; i++) {
          await slashContract.connect(validators[3]).slash(validators[1].address);
        }
      });

      it('Should the validator set get updated (excluding the slashed validator)', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });

        await ValidatorSetExpects.emitValidatorSetUpdatedEvent(
          wrapUpTx,
          [validators[0], validators[2], validators[3]].map((_) => _.address).reverse()
        );
      });

      it('Should the validators in the previous epoch (including slashed one) got slashing counter reset, when the epoch ends', async () => {
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await validatorContract.endPeriod();
          wrapUpTx = await validatorContract.wrapUpEpoch();
        });
        // TODO: slash someone here and check the slash indicator
      });
    });
  });
});
