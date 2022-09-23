import { BigNumber } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  TransparentUpgradeableProxyV2__factory,
  Maintenance,
  Maintenance__factory,
  MockValidatorSet__factory,
  MockValidatorSet,
} from '../../src/types';
import { SlashType } from '../../src/script/slash-indicator';
import { Network, slashIndicatorConf } from '../../src/config';

let slashContract: SlashIndicator;
let maintenanceContract: Maintenance;

let deployer: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let mockValidatorsContract: MockValidatorSet;
let vagabond: SignerWithAddress;
let coinbases: SignerWithAddress[];
let localIndicators: number[];
let felonyThreshold: number;
let misdemeanorThreshold: number;

const increaseLocalCounterForValidatorAt = (idx: number, value?: number) => {
  value = value ?? 1;
  localIndicators[idx] += value;
};

const setLocalCounterForValidatorAt = (idx: number, value: number) => {
  localIndicators[idx] = value;
};

const resetLocalCounterForValidatorAt = (idx: number) => {
  localIndicators[idx] = 0;
};

const validateIndicatorAt = async (idx: number) => {
  expect(localIndicators[idx]).to.eq(await slashContract.currentUnavailabilityIndicator(coinbases[idx].address));
};

describe('Slash indicator test', () => {
  before(async () => {
    [deployer, proxyAdmin, vagabond, ...coinbases] = await ethers.getSigners();
    localIndicators = Array<number>(coinbases.length).fill(0);

    if (network.name == Network.Hardhat) {
      slashIndicatorConf[network.name] = {
        misdemeanorThreshold: 5,
        felonyThreshold: 10, // set low threshold to get rid of 40000ms of test timeout
        slashFelonyAmount: BigNumber.from(10).pow(18).mul(1), // 10 RON
        slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
        felonyJailBlocks: 28800 * 2, // jails for 2 days
      };
    }

    mockValidatorsContract = await new MockValidatorSet__factory(deployer).deploy(
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      0,
      0,
      0
    );
    maintenanceContract = await new Maintenance__factory(deployer).deploy();
    const logicContract = await new SlashIndicator__factory(deployer).deploy();
    const proxyContract = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        mockValidatorsContract.address,
        maintenanceContract.address,
        slashIndicatorConf[network.name]!.misdemeanorThreshold,
        slashIndicatorConf[network.name]!.felonyThreshold,
        slashIndicatorConf[network.name]!.slashFelonyAmount,
        slashIndicatorConf[network.name]!.slashDoubleSignAmount,
        slashIndicatorConf[network.name]!.felonyJailBlocks,
      ])
    );
    slashContract = SlashIndicator__factory.connect(proxyContract.address, deployer);
    [misdemeanorThreshold, felonyThreshold] = (await slashContract.getSlashThresholds()).map((_) => _.toNumber());
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Single flow test', async () => {
    describe('Unauthorized test', async () => {
      it('Should non-coinbase cannot call slash', async () => {
        await expect(slashContract.connect(vagabond).slash(coinbases[0].address)).to.revertedWith(
          'SlashIndicator: method caller must be coinbase'
        );
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 1;

        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        let tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');
        setLocalCounterForValidatorAt(slasheeIdx, 1);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        const slasherIdx = 0;
        let tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasherIdx].address);
        expect(tx).to.not.emit(slashContract, 'UnavailabilitySlashed');

        resetLocalCounterForValidatorAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        let tx = slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not able to slash more than one validator in one block', async () => {
        const slasherIdx = 0;
        const slasheeIdx1 = 1;
        const slasheeIdx2 = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx1].address);
        let tx = slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx2].address);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        increaseLocalCounterForValidatorAt(slasheeIdx1);
        await validateIndicatorAt(slasheeIdx1);
        setLocalCounterForValidatorAt(slasheeIdx2, 1);
        await validateIndicatorAt(slasheeIdx1);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for misdemeanor (slash tier-1)', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < misdemeanorThreshold; i++) {
          tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        }
        expect(tx)
          .to.emit(slashContract, 'UnavailabilitySlashed')
          .withArgs(coinbases[1].address, SlashType.MISDEMEANOR);
        setLocalCounterForValidatorAt(slasheeIdx, misdemeanorThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter is in between misdemeanor (tier-1) and felony (tier-2) thresholds ', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        expect(tx).not.to.emit(slashContract, 'UnavailabilitySlashed');
      });

      it('Should sync with validator set for felony (slash tier-2)', async () => {
        let tx;
        const slasherIdx = 0;
        const slasheeIdx = 4;

        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);

          if (i == misdemeanorThreshold - 1) {
            expect(tx)
              .to.emit(slashContract, 'UnavailabilitySlashed')
              .withArgs(coinbases[1].address, SlashType.MISDEMEANOR);
          }
        }

        expect(tx).to.emit(slashContract, 'UnavailabilitySlashed').withArgs(coinbases[1].address, SlashType.FELONY);
        setLocalCounterForValidatorAt(slasheeIdx, felonyThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter exceeds felony threshold (tier-2) ', async () => {
        let tx;
        const slasherIdx = 1;
        const slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        tx = await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        expect(tx).not.to.emit(slashContract, 'UnavailabilitySlashed');
      });
    });

    describe('Resetting counter', async () => {
      it('Should the counter reset for one validator when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdx = 5;
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdx].address);
        }

        setLocalCounterForValidatorAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await mockValidatorsContract.endPeriod();

        resetLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should the counter reset for multiple validators when the period ended', async () => {
        const slasherIdx = 0;
        const slasheeIdxs = [6, 7, 8, 9, 10];
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          for (let j = 0; j < slasheeIdxs.length; j++) {
            await slashContract.connect(coinbases[slasherIdx]).slash(coinbases[slasheeIdxs[j]].address);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          setLocalCounterForValidatorAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await mockValidatorsContract.endPeriod();

        for (let j = 0; j < slasheeIdxs.length; j++) {
          resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });
  });
});
