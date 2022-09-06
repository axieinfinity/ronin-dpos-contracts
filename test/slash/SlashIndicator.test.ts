import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  MockEmptyValidatorSet,
  MockEmptyValidatorSet__factory,
} from '../../src/types';
import { Address } from 'hardhat-deploy/dist/types';

let slashContract: SlashIndicator;

let deployer: SignerWithAddress;
let dummyValidatorsContract: MockEmptyValidatorSet;
let vagabond: SignerWithAddress;
let coinbases: SignerWithAddress[];
let defaultCoinbase: Address;
let localIndicators: number[];

enum SlashType {
  UNKNOWN,
  MISDEMAENOR,
  FELONY,
  DOUBLE_SIGNING,
}

const getBlockNumber = async () => {
  return network.provider.send('eth_blockNumber');
};

const resetCoinbase = async () => {
  await network.provider.send('hardhat_setCoinbase', [defaultCoinbase]);
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

const setLocalCounterForValidatorAt = async (_index: number, _value: number) => {
  localIndicators[_index] = _value;
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
  let felonyThreshold: number;
  let misdemeanorThreshold: number;

  before(async () => {
    [deployer, vagabond, ...coinbases] = await ethers.getSigners();

    localIndicators = Array<number>(coinbases.length).fill(0);

    dummyValidatorsContract = await new MockEmptyValidatorSet__factory(deployer).deploy();
    slashContract = await new SlashIndicator__factory(deployer).deploy(dummyValidatorsContract.address);
    await dummyValidatorsContract.connect(deployer).setSlashingContract(slashContract.address);

    let thresholds = await slashContract.getSlashThresholds();
    felonyThreshold = thresholds[0].toNumber();
    misdemeanorThreshold = thresholds[1].toNumber();

    defaultCoinbase = await network.provider.send('eth_coinbase');
    console.log('Default coinbase:', defaultCoinbase);
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
          'SlashIndicator: method caller is not the validator contract'
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
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        expect(tx).to.be.revertedWith('SlashIndicator: cannot slash twice in one block');

        await setLocalCounterForValidatorAt(slasheeIdx, 1);
        await validateIndicatorAt(slasheeIdx);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for felony', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdx = 3;

        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.FELONY);
        await setLocalCounterForValidatorAt(slasheeIdx, felonyThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should sync with validator set for misdemeanor', async () => {
        let tx;
        let slasherIdx = 1;
        let slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < misdemeanorThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.MISDEMAENOR);
        await setLocalCounterForValidatorAt(slasheeIdx, misdemeanorThreshold);
        await validateIndicatorAt(slasheeIdx);
      });
    });

    describe('Reseting counter', async () => {
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

        tx = await dummyValidatorsContract.resetCounters([coinbases[slasheeIdx].address]);
        expect(tx).to.emit(slashContract, 'UnavailabilityIndicatorReset').withArgs(coinbases[slasheeIdx].address);

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

        tx = await dummyValidatorsContract.resetCounters(slasheeIdxs.map((_) => coinbases[_].address));

        for (let j = 0; j < slasheeIdxs.length; j++) {
          expect(tx).to.emit(slashContract, 'UnavailabilityIndicatorReset').withArgs(coinbases[slasheeIdxs[j]].address);
          await resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });
  });

  describe('Integration test', async () => {});
});
