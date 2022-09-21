import { BigNumber } from 'ethers';
import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  MockValidatorSetForSlash,
  MockValidatorSetForSlash__factory,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Address } from 'hardhat-deploy/dist/types';
import { SlashType } from '../../src/script/slash-indicator';
import { Network, slashIndicatorConf } from '../../src/config';
import { expects as SlashExpects } from '../helpers/slash-indicator';

let slashContract: SlashIndicator;

let deployer: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let mockValidatorsContract: MockValidatorSetForSlash;
let vagabond: SignerWithAddress;
let coinbases: SignerWithAddress[];
let defaultCoinbase: Address;
let localIndicators: number[];
let felonyThreshold: number;
let misdemeanorThreshold: number;

const resetCoinbase = async () => {
  await network.provider.send('hardhat_setCoinbase', [defaultCoinbase]);
};

const increaseLocalCounterForValidatorAt = async (_index: number, _increase?: number) => {
  _increase = _increase ?? 1;
  localIndicators[_index] = (localIndicators[_index] + _increase) % felonyThreshold;
};

const setLocalCounterForValidatorAt = async (_index: number, _value: number) => {
  localIndicators[_index] = _value % felonyThreshold;
};

const resetLocalCounterForValidatorAt = async (_index: number) => {
  localIndicators[_index] = 0;
};

const validateIndicatorAt = async (_index: number) => {
  expect(localIndicators[_index]).to.eq(await slashContract.getSlashIndicator(coinbases[_index].address));
};

const doSlash = async (slasher: SignerWithAddress, slashee: SignerWithAddress) => {
  return slashContract.connect(slasher).slash(slashee.address);
};

describe('Slash indicator test', () => {
  before(async () => {
    [deployer, proxyAdmin, vagabond, ...coinbases] = await ethers.getSigners();
    localIndicators = Array<number>(coinbases.length).fill(0);
    defaultCoinbase = await network.provider.send('eth_coinbase');

    if (network.name == Network.Hardhat) {
      slashIndicatorConf[network.name] = {
        misdemeanorThreshold: 10,
        felonyThreshold: 20, // set low threshold to get rid of 40000ms of test timeout
        slashFelonyAmount: BigNumber.from(10).pow(18).mul(1), // 10 RON
        slashDoubleSignAmount: BigNumber.from(10).pow(18).mul(10), // 10 RON
        felonyJailBlocks: 28800 * 2, // jails for 2 days
      };
    }

    mockValidatorsContract = await new MockValidatorSetForSlash__factory(deployer).deploy();
    const logicContract = await new SlashIndicator__factory(deployer).deploy();
    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        mockValidatorsContract.address,
        slashIndicatorConf[network.name]!.misdemeanorThreshold,
        slashIndicatorConf[network.name]!.felonyThreshold,
        slashIndicatorConf[network.name]!.slashFelonyAmount,
        slashIndicatorConf[network.name]!.slashDoubleSignAmount,
        slashIndicatorConf[network.name]!.felonyJailBlocks,
      ])
    );
    slashContract = SlashIndicator__factory.connect(proxyContract.address, deployer);
    await mockValidatorsContract.connect(deployer).setSlashingContract(slashContract.address);

    [misdemeanorThreshold, felonyThreshold] = (await slashContract.getSlashThresholds()).map((_) => _.toNumber());
  });

  describe('Single flow test', async () => {
    describe('Unauthorized test', async () => {
      it('Should non-coinbase cannot call slash', async () => {
        await expect(slashContract.connect(vagabond).slash(coinbases[0].address)).to.revertedWith(
          'SlashIndicator: method caller is not the coinbase'
        );
      });

      it('Should non-validatorContract cannot call reset counter', async () => {
        await expect(slashContract.connect(vagabond).resetCounters([coinbases[0].address])).to.revertedWith(
          'HasValidatorContract: method caller must be validator contract'
        );
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        let slasherIdx = 0;
        let slasheeIdx = 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        let tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        expect(tx).to.not.emit(slashContract, 'ValidatorSlashed');
        setLocalCounterForValidatorAt(slasheeIdx, 1);
        validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        let slasherIdx = 0;
        let tx = await doSlash(coinbases[slasherIdx], coinbases[slasherIdx]);
        expect(tx).to.not.emit(slashContract, 'ValidatorSlashed');

        await resetLocalCounterForValidatorAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        let slasherIdx = 0;
        let slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        let tx = doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        await increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not able to slash more than one validator in one block', async () => {
        let slasherIdx = 0;
        let slasheeIdx1 = 1;
        let slasheeIdx2 = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx1]);
        let tx = doSlash(coinbases[slasherIdx], coinbases[slasheeIdx2]);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        await increaseLocalCounterForValidatorAt(slasheeIdx1);
        await validateIndicatorAt(slasheeIdx1);
        await setLocalCounterForValidatorAt(slasheeIdx2, 1);
        await validateIndicatorAt(slasheeIdx1);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for misdemeanor (slash tier-1)', async () => {
        let tx;
        let slasherIdx = 1;
        let slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < misdemeanorThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.MISDEMEANOR);
        await setLocalCounterForValidatorAt(slasheeIdx, misdemeanorThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter is in between misdemeanor (tier-1) and felony (tier-2) thresholds ', async () => {
        let tx;
        let slasherIdx = 1;
        let slasheeIdx = 3;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        await increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        expect(tx).not.to.emit(slashContract, 'ValidatorSlashed');
      });

      it('Should sync with validator set for felony (slash tier-2)', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdx = 4;

        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);

          if (i == misdemeanorThreshold - 1) {
            expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.MISDEMEANOR);
          }
        }

        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.FELONY);
        await setLocalCounterForValidatorAt(slasheeIdx, felonyThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not sync with validator set when the indicator counter exceeds felony threshold (tier-2) ', async () => {
        let tx;
        let slasherIdx = 1;
        let slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        await increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);

        expect(tx).not.to.emit(slashContract, 'ValidatorSlashed');
      });
    });

    describe('Resetting counter', async () => {
      it('Should validator set contract reset counter for one validator', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdx = 5;
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        await setLocalCounterForValidatorAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await resetCoinbase();

        tx = await mockValidatorsContract.resetCounters([coinbases[slasheeIdx].address]);
        await SlashExpects.emitUnavailabilityIndicatorsResetEvent(tx, [coinbases[slasheeIdx].address]);

        await resetLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator set contract reset counter for multiple validators', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdxs = [6, 7, 8, 9, 10];
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          for (let j = 0; j < slasheeIdxs.length; j++) {
            await doSlash(coinbases[slasherIdx], coinbases[slasheeIdxs[j]]);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          await setLocalCounterForValidatorAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await resetCoinbase();

        tx = await mockValidatorsContract.resetCounters(slasheeIdxs.map((_) => coinbases[_].address));

        await SlashExpects.emitUnavailabilityIndicatorsResetEvent(
          tx,
          slasheeIdxs.map((_) => coinbases[_].address)
        );

        for (let j = 0; j < slasheeIdxs.length; j++) {
          await resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });
  });
});
