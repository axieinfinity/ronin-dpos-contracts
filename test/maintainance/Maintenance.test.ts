import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, BigNumberish } from 'ethers';

import {
  RoninValidatorSet,
  Maintenance,
  Maintenance__factory,
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetSorting__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
} from '../../src/types';
import { initTest } from '../helpers/fixture';
import { EpochController } from '../helpers/ronin-validator-set';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let localEpochController: EpochController;

const misdemeanorThreshold = 50;
const felonyThreshold = 150;
const maxValidatorNumber = 4;
const numberOfBlocksInEpoch = 600;
const numberOfEpochsInPeriod = 48;
const minValidatorBalance = BigNumber.from(100);
const minMaintenanceBlockPeriod = 100;
const maxMaintenanceBlockPeriod = 1000;
const minOffset = 200;

let startedAtBlock: BigNumberish = 0;
let endedAtBlock: BigNumberish = 0;
let currentBlock: number;

describe('Maintenance test', () => {
  before(async () => {
    [deployer, coinbase, governor, ...validatorCandidates] = await ethers.getSigners();
    const {
      maintenanceContractAddress,
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
    } = await initTest('Maintenance')({
      trustedOrganizations: [governor.address].map((addr) => ({ addr, weight: 100 })),
      misdemeanorThreshold,
      felonyThreshold,
    });
    maintenanceContract = Maintenance__factory.connect(maintenanceContractAddress, deployer);
    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetSorting__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetSorting__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .applyValidatorCandidate(
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

    localEpochController = new EpochController(minOffset, numberOfBlocksInEpoch, numberOfEpochsInPeriod);

    await localEpochController.mineToBeforeEndOfEpoch();

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

    it('Should be not able to schedule maintenance with invalid offset', async () => {
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

    it('Should be not able to schedule maintenance in case of: start block >= end block', async () => {
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

    it('Should be not able to schedule maintenance when the maintenance period is too small or large', async () => {
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

    it('Should be not able to schedule maintenance when the start block is not at the start of an epoch', async () => {
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock).add(1);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock.add(minMaintenanceBlockPeriod));

      expect(startedAtBlock.mod(numberOfBlocksInEpoch)).not.eq(0);
      expect(endedAtBlock.mod(numberOfBlocksInEpoch)).eq(numberOfBlocksInEpoch - 1);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is not at the start of an epoch');
    });

    it('Should be not able to schedule maintenance when the end block is not at the end of an epoch', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock.add(minMaintenanceBlockPeriod)).add(1);

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
    it('Should not be able to schedule maintenance using unauthorized account', async () => {
      await expect(maintenanceContract.connect(deployer).schedule(validatorCandidates[0].address, 0, 100)).revertedWith(
        'Maintenance: method caller must be a candidate admin'
      );
    });

    it('Should not be able to schedule maintenance for non-validator address', async () => {
      await expect(maintenanceContract.connect(validatorCandidates[0]).schedule(deployer.address, 0, 100)).revertedWith(
        'Maintenance: consensus address must be a validator'
      );
    });

    it('Should be able to schedule maintenance using validator admin account', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock).add(numberOfBlocksInEpoch);
      endedAtBlock = localEpochController.calculateEndOfEpoch(
        BigNumber.from(startedAtBlock).add(minMaintenanceBlockPeriod)
      );

      const tx = await maintenanceContract
        .connect(validatorCandidates[0])
        .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock);
      await expect(tx)
        .emit(maintenanceContract, 'MaintenanceScheduled')
        .withArgs(validatorCandidates[0].address, [startedAtBlock, endedAtBlock]);
      expect(await maintenanceContract.scheduled(validatorCandidates[0].address)).true;
    });

    it('Should not be able to schedule maintenance again', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: already scheduled');
    });

    it('Should be able to schedule maintenance using another validator admin account', async () => {
      await maintenanceContract
        .connect(validatorCandidates[1])
        .schedule(validatorCandidates[1].address, startedAtBlock, endedAtBlock);
    });

    it('Should not be able to schedule maintenance once there are many schedules', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[3])
          .schedule(validatorCandidates[3].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: exceeds total of schedules');
    });

    it('Should the validator still appear in the validator list since it is not maintenance time yet', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
    });

    it('Should the validator not appear in the validator list since the maintenance is started', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.slice(2).map((_) => _.address));
    });

    it('[Slash Integration] Should not be able to slash the validator in maintenance time', async () => {
      await slashContract.connect(coinbase).slash(validatorCandidates[0].address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[0].address)).eq(0);
      await slashContract.connect(coinbase).slash(validatorCandidates[1].address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[1].address)).eq(0);
    });

    it('[Slash Integration] Should the unavailability thresholds of the validator is rescaled', async () => {
      currentBlock = await ethers.provider.getBlockNumber();
      const thresholds = await slashContract.unavailabilityThresholdsOf(validatorCandidates[0].address, currentBlock);

      const blockLength = BigNumber.from(numberOfBlocksInEpoch * numberOfEpochsInPeriod);
      const diff = blockLength.sub(BigNumber.from(endedAtBlock).sub(startedAtBlock).add(1));

      expect(thresholds).eql([
        diff.mul(misdemeanorThreshold).div(blockLength),
        diff.mul(felonyThreshold).div(blockLength),
      ]);
    });

    it('Should the validator appear in the validator list since the maintenance time is ended', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.address));
    });

    it('Should not be able to schedule maintenance twice in a period', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0])
          .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: schedule twice in a period is not allowed');
    });

    it('[Slash Integration] Should the unavailability thresholds reset in the next period', async () => {
      await network.provider.send('hardhat_mine', [
        ethers.utils.hexStripZeros(BigNumber.from(numberOfBlocksInEpoch * numberOfEpochsInPeriod).toHexString()),
      ]);
      currentBlock = await ethers.provider.getBlockNumber();
      const thresholds = await slashContract.unavailabilityThresholdsOf(validatorCandidates[0].address, currentBlock);
      expect(thresholds.map((v) => v.toNumber())).eql([misdemeanorThreshold, felonyThreshold]);
    });

    it('Should be able to schedule in the next period', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock);
      await maintenanceContract
        .connect(validatorCandidates[0])
        .schedule(validatorCandidates[0].address, startedAtBlock, endedAtBlock);
    });
  });
});
