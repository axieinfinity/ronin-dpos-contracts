import { expect } from 'chai';
import { deployments, ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockRoninValidatorSetExtends,
  MockRoninValidatorSetExtends__factory,
  ProxyAdmin__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
  Maintenance,
  Maintenance__factory,
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  StakingVesting,
  Staking__factory,
} from '../../src/types';
import { BigNumber, BigNumberish } from 'ethers';
import {
  Network,
  slashIndicatorConf,
  roninValidatorSetConf,
  stakingConfig,
  stakingVestingConfig,
  initAddress,
  MaintenanceConfig,
} from '../../src/config';

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetExtends;

const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;
const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;

const maxValidatorNumber = 4;
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

let startedAtBlock: BigNumberish = 0;
let endedAtBlock: BigNumberish = 0;
let currentBlock: number;

const calculateStartOfEpoch = (block: number) =>
  BigNumber.from(
    Math.floor((block + minOffset + numberOfBlocksInEpoch - 1) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch
  );
const diffToEndEpoch = (block: BigNumberish) =>
  BigNumber.from(numberOfBlocksInEpoch).sub(BigNumber.from(block).mod(numberOfBlocksInEpoch)).sub(1);
const calculateEndOfEpoch = (block: BigNumberish) => BigNumber.from(block).add(diffToEndEpoch(block));
const mineToBeforeEndOfEpoch = async () => {
  let number = diffToEndEpoch(await ethers.provider.getBlockNumber()).sub(1);
  if (number.lt(0)) {
    number = number.add(numberOfBlocksInEpoch);
  }
  return network.provider.send('hardhat_mine', [ethers.utils.hexStripZeros(number.toHexString())]);
};

// TODO: create fixture to avoid repeating code
describe('Maintenance test', () => {
  before(async () => {
    [deployer, coinbase, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();

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
      'CalculateAddresses',
      'RoninValidatorSetProxy',
      'SlashIndicatorProxy',
      'StakingProxy',
      'MaintenanceProxy',
      'StakingVestingProxy',
    ]);

    const MaintenanceDeployment = await deployments.get('MaintenanceProxy');
    const slashContractDeployment = await deployments.get('SlashIndicatorProxy');
    const stakingContractDeployment = await deployments.get('StakingProxy');
    const validatorContractDeployment = await deployments.get('RoninValidatorSetProxy');

    maintenanceContract = Maintenance__factory.connect(MaintenanceDeployment.address, deployer);
    slashContract = SlashIndicator__factory.connect(slashContractDeployment.address, deployer);
    stakingContract = Staking__factory.connect(stakingContractDeployment.address, deployer);
    validatorContract = MockRoninValidatorSetExtends__factory.connect(validatorContractDeployment.address, deployer);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .proposeValidator(
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          validatorCandidates[i].address,
          1,
          { value: minValidatorBalance.add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    await network.provider.send('hardhat_mine', [
      ethers.utils.hexStripZeros(BigNumber.from(numberOfBlocksInEpoch * numberOfEpochsInPeriod).toHexString()),
    ]);
    await mineToBeforeEndOfEpoch();

    await validatorContract.connect(coinbase).wrapUpEpoch();
    expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Configuration test', () => {
    before(async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
    });

    it('Should be not able to request maintenance with invalid offset', async () => {
      startedAtBlock = 0;
      endedAtBlock = 100;
      expect(startedAtBlock - currentBlock).lt(minOffset);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid offset size');

      startedAtBlock = currentBlock;
      endedAtBlock = currentBlock + 1000;
      expect(startedAtBlock - currentBlock).lt(minOffset);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid offset size');
    });

    it('Should be not able to request maintenance in case of: start block >= end block', async () => {
      startedAtBlock = currentBlock + minOffset;
      endedAtBlock = currentBlock;
      expect(endedAtBlock).lte(startedAtBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block must be less than end block');

      endedAtBlock = startedAtBlock;
      expect(endedAtBlock).lte(startedAtBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block must be less than end block');
    });

    it('Should be not able to request maintenance when the maintenance period is too small or large', async () => {
      endedAtBlock = BigNumber.from(startedAtBlock).add(1);
      expect(endedAtBlock.sub(startedAtBlock)).lt(minMaintenanceBlockPeriod);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid maintenance block period');

      endedAtBlock = BigNumber.from(startedAtBlock).add(maxMaintenanceBlockPeriod).add(1);
      expect(endedAtBlock.sub(startedAtBlock)).gt(maxMaintenanceBlockPeriod);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid maintenance block period');
    });

    it('Should be not able to request maintenance when the start block is not at the start of an epoch', async () => {
      startedAtBlock = calculateStartOfEpoch(currentBlock).add(1);
      endedAtBlock = calculateEndOfEpoch(startedAtBlock.add(minMaintenanceBlockPeriod));

      expect(startedAtBlock.mod(numberOfBlocksInEpoch)).not.eq(0);
      expect(endedAtBlock.mod(numberOfBlocksInEpoch)).eq(numberOfBlocksInEpoch - 1);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is not at the start of an epoch');
    });

    it('Should be not able to request maintenance when the end block is not at the end of an epoch', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = calculateStartOfEpoch(currentBlock);
      endedAtBlock = calculateEndOfEpoch(startedAtBlock.add(minMaintenanceBlockPeriod)).add(1);

      expect(startedAtBlock.mod(numberOfBlocksInEpoch)).eq(0);
      expect(endedAtBlock.mod(numberOfBlocksInEpoch)).not.eq(numberOfBlocksInEpoch - 1);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: end block is not at the end of an epoch');
    });
  });

  describe('Schedule test', () => {
    it('Should not be able to request maintenance using unauthorized account', async () => {
      await expect(maintenanceContract.connect(deployer).schedule(validatorCandidates[0].address, 0, 100)).revertedWith(
        'Maintenance: method caller must be a candidate admin'
      );
    });

    it('Should not be able to request maintenance for non-validator address', async () => {
      await expect(maintenanceContract.connect(validatorCandidates[0]).schedule(deployer.address, 0, 100)).revertedWith(
        'Maintenance: consensus address must be a validator'
      );
    });

    it('Should be able to request maintenance using validator admin account', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = calculateStartOfEpoch(currentBlock).add(numberOfBlocksInEpoch);
      endedAtBlock = calculateEndOfEpoch(BigNumber.from(startedAtBlock).add(minMaintenanceBlockPeriod));

      const tx = await maintenanceContract
        .connect(validatorCandidates[0])
        .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock);
      await expect(tx)
        .emit(maintenanceContract, 'MaintenanceScheduled')
        .withArgs(validatorCandidates[0].address, [startedAtBlock, endedAtBlock]);
      expect(await maintenanceContract.scheduled(validatorCandidates[0].address)).true;
    });

    it('Should not be able to request maintenance again', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: already scheduled');
    });

    it('Should be able to request maintenance using another validator admin account', async () => {
      await maintenanceContract
        .connect(validatorCandidates[1])
        .schedule(validatorCandidates[1].address, startedAtBlock, endedAtBlock);
    });

    it('Should not be able to request maintenance once there are many schedules', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[3])
          .schedule(validatorCandidates[3].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: exceeds total of schedules');
    });

    it('Should the validator still appear in the validator list since it is not maintenance time yet', async () => {
      await mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
    });

    it('Should the validator not appear in the validator list since the maintenance is started', async () => {
      await mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.slice(2).map((_) => _.address));
    });

    it('Should not be able to slash the validator in maintenance time', async () => {
      await slashContract.connect(coinbase).slash(validatorCandidates[0].address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[0].address)).eq(0);
      await slashContract.connect(coinbase).slash(validatorCandidates[1].address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[1].address)).eq(0);
    });

    it('Should the validator appear in the validator list since the maintenance time is ended', async () => {
      await mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
    });
  });
});
