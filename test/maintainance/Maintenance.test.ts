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
  MockRoninValidatorSetOverridePrecompile__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
} from '../../src/types';
import { initTest } from '../helpers/fixture';
import { EpochController, expects as ValidatorSetExpects } from '../helpers/ronin-validator-set';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';

let coinbase: SignerWithAddress;
let deployer: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];

let maintenanceContract: Maintenance;
let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: RoninValidatorSet;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let localEpochController: EpochController;

const unavailabilityTier1Threshold = 50;
const unavailabilityTier2Threshold = 150;
const maxValidatorNumber = 4;
const numberOfBlocksInEpoch = 600;
const minValidatorStakingAmount = BigNumber.from(100);
const minMaintenanceDurationInBlock = 100;
const maxMaintenanceDurationInBlock = 1000;
const minOffsetToStartSchedule = 200;
const maxOffsetToStartSchedule = 200 * 7;

let startedAtBlock: BigNumberish = 0;
let endedAtBlock: BigNumberish = 0;
let currentBlock: number;

describe('Maintenance test', () => {
  before(async () => {
    [deployer, coinbase, ...signers] = await ethers.getSigners();
    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(signers.slice(0, maxValidatorNumber * 3));

    const {
      maintenanceContractAddress,
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninGovernanceAdminAddress,
    } = await initTest('Maintenance')({
      slashIndicatorArguments: {
        unavailabilitySlashing: {
          unavailabilityTier1Threshold,
          unavailabilityTier2Threshold,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        numberOfBlocksInEpoch,
      },
      maintenanceArguments: {
        minOffsetToStartSchedule,
        maxOffsetToStartSchedule,
        minMaintenanceDurationInBlock,
        maxMaintenanceDurationInBlock,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
    });
    maintenanceContract = Maintenance__factory.connect(maintenanceContractAddress, deployer);
    slashContract = SlashIndicator__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    validatorContract = MockRoninValidatorSetOverridePrecompile__factory.connect(validatorContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetOverridePrecompile__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          validatorCandidates[i].bridgeOperator.address,
          1,
          { value: minValidatorStakingAmount.add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    localEpochController = new EpochController(minOffsetToStartSchedule, numberOfBlocksInEpoch);
    await localEpochController.mineToBeforeEndOfEpoch(2);
    let tx = await validatorContract.connect(coinbase).wrapUpEpoch();
    await ValidatorSetExpects.emitValidatorSetUpdatedEvent(
      tx,
      await validatorContract.currentPeriod(),
      validatorCandidates.map((_) => _.consensusAddr.address)
    );

    expect(await validatorContract.getValidators()).eql(validatorCandidates.map((_) => _.consensusAddr.address));
    expect(await validatorContract.getBlockProducers()).eql(validatorCandidates.map((_) => _.consensusAddr.address));
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Configuration test', () => {
    before(async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
    });

    it('Should be not able to schedule maintenance with invalid start block', async () => {
      startedAtBlock = 0;
      endedAtBlock = 100;
      expect(startedAtBlock - currentBlock).lt(minOffsetToStartSchedule);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is out of offset');

      startedAtBlock = currentBlock;
      endedAtBlock = currentBlock + 1000;
      expect(startedAtBlock - currentBlock).lt(minOffsetToStartSchedule);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is out of offset');

      startedAtBlock = currentBlock + maxOffsetToStartSchedule + 1;
      endedAtBlock = startedAtBlock + 1000;
      expect(startedAtBlock - currentBlock).gt(maxOffsetToStartSchedule);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is out of offset');
    });

    it('Should be not able to schedule maintenance in case of: start block >= end block', async () => {
      startedAtBlock = currentBlock + minOffsetToStartSchedule;
      endedAtBlock = currentBlock;
      expect(endedAtBlock).lte(startedAtBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block must be less than end block');

      endedAtBlock = startedAtBlock;
      expect(endedAtBlock).lte(startedAtBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block must be less than end block');
    });

    it('Should be not able to schedule maintenance when the maintenance period is too small or large', async () => {
      endedAtBlock = BigNumber.from(startedAtBlock).add(1);
      expect(endedAtBlock.sub(startedAtBlock)).lt(minMaintenanceDurationInBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid maintenance duration');

      endedAtBlock = BigNumber.from(startedAtBlock).add(maxMaintenanceDurationInBlock).add(1);
      expect(endedAtBlock.sub(startedAtBlock)).gt(maxMaintenanceDurationInBlock);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: invalid maintenance duration');
    });

    it('Should be not able to schedule maintenance when the start block is not at the start of an epoch', async () => {
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock).add(1);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock.add(minMaintenanceDurationInBlock));

      expect(startedAtBlock.mod(numberOfBlocksInEpoch)).not.eq(0);
      expect(endedAtBlock.mod(numberOfBlocksInEpoch)).eq(numberOfBlocksInEpoch - 1);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: start block is not at the start of an epoch');
    });

    it('Should be not able to schedule maintenance when the end block is not at the end of an epoch', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock.add(minMaintenanceDurationInBlock)).add(1);

      expect(startedAtBlock.mod(numberOfBlocksInEpoch)).eq(0);
      expect(endedAtBlock.mod(numberOfBlocksInEpoch)).not.eq(numberOfBlocksInEpoch - 1);
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: end block is not at the end of an epoch');
    });
  });

  describe('Schedule test', () => {
    it('Should not be able to schedule maintenance using unauthorized account', async () => {
      await expect(
        maintenanceContract.connect(deployer).schedule(validatorCandidates[0].consensusAddr.address, 0, 100)
      ).revertedWith('Maintenance: method caller must be a candidate admin');
    });

    it('Should not be able to schedule maintenance for non-validator address', async () => {
      await expect(
        maintenanceContract.connect(validatorCandidates[0].candidateAdmin).schedule(deployer.address, 0, 100)
      ).revertedWith('Maintenance: consensus address must be a block producer');
    });

    it('Should be able to schedule maintenance using validator admin account', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock).add(numberOfBlocksInEpoch);
      endedAtBlock = localEpochController.calculateEndOfEpoch(
        BigNumber.from(startedAtBlock).add(minMaintenanceDurationInBlock)
      );

      const tx = await maintenanceContract
        .connect(validatorCandidates[0].candidateAdmin)
        .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock);
      await expect(tx)
        .emit(maintenanceContract, 'MaintenanceScheduled')
        .withArgs(validatorCandidates[0].consensusAddr.address, [startedAtBlock, endedAtBlock]);
      expect(await maintenanceContract.checkScheduled(validatorCandidates[0].consensusAddr.address)).true;
    });

    it('Should not be able to schedule maintenance again', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[0].candidateAdmin)
          .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: already scheduled');
    });

    it('Should be able to schedule maintenance for another validator using their admin account', async () => {
      await maintenanceContract
        .connect(validatorCandidates[1].candidateAdmin)
        .schedule(validatorCandidates[1].consensusAddr.address, startedAtBlock, endedAtBlock);
    });

    it('Should not be able to schedule maintenance once there are many schedules', async () => {
      await expect(
        maintenanceContract
          .connect(validatorCandidates[3].candidateAdmin)
          .schedule(validatorCandidates[3].consensusAddr.address, startedAtBlock, endedAtBlock)
      ).revertedWith('Maintenance: exceeds total of schedules');
    });

    it('Should the validator still appear in the block producer list since it is not maintenance time yet', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      let tx = await validatorContract.connect(coinbase).wrapUpEpoch();
      expect(await validatorContract.getBlockProducers()).eql(validatorCandidates.map((_) => _.consensusAddr.address));
    });

    it('Should the validator not appear in the block producer list since the maintenance is started', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      let tx = await validatorContract.connect(coinbase).wrapUpEpoch();
      let expectingBlockProducerSet = validatorCandidates.slice(2).map((_) => _.consensusAddr.address);
      await ValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
        tx!,
        await validatorContract.currentPeriod(),
        expectingBlockProducerSet
      );
      expect(await validatorContract.getBlockProducers()).eql(
        validatorCandidates.slice(2).map((_) => _.consensusAddr.address)
      );
    });

    it('[Slash Integration] Should not be able to slash the validator in maintenance time', async () => {
      await slashContract.connect(coinbase).slashUnavailability(validatorCandidates[0].consensusAddr.address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[0].consensusAddr.address)).eq(0);
      await slashContract.connect(coinbase).slashUnavailability(validatorCandidates[1].consensusAddr.address);
      expect(await slashContract.currentUnavailabilityIndicator(validatorCandidates[1].consensusAddr.address)).eq(0);
    });

    it('Should the validator appear in the block producer list since the maintenance time is ended', async () => {
      await localEpochController.mineToBeforeEndOfEpoch();
      let tx = await validatorContract.connect(coinbase).wrapUpEpoch();
      let expectingBlockProducerSet = validatorCandidates.map((_) => _.consensusAddr.address);
      await ValidatorSetExpects.emitBlockProducerSetUpdatedEvent(
        tx!,
        await validatorContract.currentPeriod(),
        expectingBlockProducerSet
      );
      expect(await validatorContract.getBlockProducers()).eql(expectingBlockProducerSet);
    });

    it('Should be able to schedule again in current period when the previous maintenance is done', async () => {
      currentBlock = (await ethers.provider.getBlockNumber()) + 1;
      startedAtBlock = localEpochController.calculateStartOfEpoch(currentBlock);
      endedAtBlock = localEpochController.calculateEndOfEpoch(startedAtBlock);
      await maintenanceContract
        .connect(validatorCandidates[0].candidateAdmin)
        .schedule(validatorCandidates[0].consensusAddr.address, startedAtBlock, endedAtBlock);
    });
  });
});
