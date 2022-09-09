import { expect } from 'chai';
import { network, ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  RoninValidatorSet__factory,
  MockRoninValidatorSetEpochSetter__factory,
  MockRoninValidatorSetEpochSetter,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Network, slashIndicatorConf, roninValidatorSetConf, stakingConfig, initAddress } from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { SlashType } from './slashType';
import { expects as RoninValidatorSetExpects } from '../../src/script/ronin-validator-set';

let slashIndicatorContract: SlashIndicator;
let stakingContract: Staking;
let roninValidatorSetContract: MockRoninValidatorSetEpochSetter;

let coinbase: SignerWithAddress;
let treasury: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const slashFelonyAmount = BigNumber.from(1);
const slashDoubleSignAmount = 1000;
const maxValidatorNumber = 4;
const minValidatorBalance = BigNumber.from(100);
const felonyJailDuration = 28800 * 2;
const misdemeanorThreshold = 10;
const felonyThreshold = 20;

const mineBatchTxs = async (fn: () => Promise<void>) => {
  await network.provider.send('evm_setAutomine', [false]);
  await fn();
  await network.provider.send('evm_mine');
  await network.provider.send('evm_setAutomine', [true]);
};

describe('Slash indicator integration test', () => {
  before(async () => {
    [coinbase, treasury, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 5);
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    if (network.name == Network.Hardhat) {
      initAddress[network.name] = {
        governanceAdmin: governanceAdmin.address,
      };
      slashIndicatorConf[network.name] = {
        misdemeanorThreshold: misdemeanorThreshold,
        felonyThreshold: felonyThreshold,
        slashFelonyAmount: slashFelonyAmount,
        slashDoubleSignAmount: slashDoubleSignAmount,
        felonyJailBlocks: felonyJailDuration,
      };
      roninValidatorSetConf[network.name] = {
        maxValidatorNumber: 21,
        numberOfBlocksInEpoch: 600,
        numberOfEpochsInPeriod: 48, // 1 day
      };
      stakingConfig[network.name] = {
        minValidatorBalance: minValidatorBalance,
        maxValidatorCandidate: maxValidatorNumber,
      };
    }

    const nonce = await deployer.getTransactionCount();
    const roninValidatorSetAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 4 });

    const slashLogicContract = await new SlashIndicator__factory(deployer).deploy();
    await slashLogicContract.deployed();

    const slashProxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      slashLogicContract.address,
      proxyAdmin.address,
      slashLogicContract.interface.encodeFunctionData('initialize', [
        slashIndicatorConf[network.name]!.misdemeanorThreshold,
        slashIndicatorConf[network.name]!.felonyThreshold,
        roninValidatorSetAddr,
        slashIndicatorConf[network.name]!.slashFelonyAmount,
        slashIndicatorConf[network.name]!.slashDoubleSignAmount,
        slashIndicatorConf[network.name]!.felonyJailBlocks,
      ])
    );
    await slashProxyContract.deployed();
    slashIndicatorContract = SlashIndicator__factory.connect(slashProxyContract.address, deployer);

    roninValidatorSetContract = await new MockRoninValidatorSetEpochSetter__factory(deployer).deploy(
      governanceAdmin.address,
      slashIndicatorContract.address,
      stakingContractAddr,
      maxValidatorNumber
    );
    await roninValidatorSetContract.deployed();

    const stakingLogicContract = await new Staking__factory(deployer).deploy();
    await stakingLogicContract.deployed();

    const stakingProxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      stakingLogicContract.address,
      proxyAdmin.address,
      stakingLogicContract.interface.encodeFunctionData('initialize', [
        roninValidatorSetContract.address,
        governanceAdmin.address,
        100,
        minValidatorBalance,
      ])
    );
    await stakingProxyContract.deployed();
    stakingContract = Staking__factory.connect(stakingProxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase()).eq(roninValidatorSetContract.address.toLowerCase());
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  describe('Integrate with Validator Set', async () => {
    describe('Slash indicator', async () => {
      describe('Configuration test', async () => {
        it('Should configs the roninValidatorSetContract correctly', async () => {
          let _validatorContract = await slashIndicatorContract.validatorContract();
          expect(_validatorContract).to.eq(roninValidatorSetContract.address);
        });
      });

      describe('Interact to Validator Set in slashing function', async () => {
        describe('Slash misdemeanor validator', async () => {
          let slasheeIdx = 1;

          it('Should the ValidatorSet contract emit event', async () => {
            for (let i = 0; i < misdemeanorThreshold - 1; i++) {
              await slashIndicatorContract.connect(coinbase).slash(validatorCandidates[slasheeIdx].address);
            }
            let tx = slashIndicatorContract.connect(coinbase).slash(validatorCandidates[slasheeIdx].address);

            await expect(tx)
              .to.emit(slashIndicatorContract, 'ValidatorSlashed')
              .withArgs(validatorCandidates[slasheeIdx].address, SlashType.MISDEMEANOR);

            await expect(tx)
              .to.emit(roninValidatorSetContract, 'ValidatorSlashed')
              .withArgs(validatorCandidates[slasheeIdx].address, 0, 0);
          });
        });

        describe.skip('Slash felony validator', async () => {
          let slasheeIdx = 2;
          let updateValidatorTx: ContractTransaction;
          let slashValidatorTx: ContractTransaction;

          before(async () => {
            await stakingContract
              .connect(validatorCandidates[slasheeIdx])
              .proposeValidator(
                validatorCandidates[slasheeIdx].address,
                validatorCandidates[slasheeIdx].address,
                2_00,
                {
                  value: minValidatorBalance,
                }
              );

            await mineBatchTxs(async () => {
              await roninValidatorSetContract.connect(coinbase).endEpoch();
              updateValidatorTx = await roninValidatorSetContract.connect(coinbase).wrapUpEpoch();
            });
            await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, [
              validatorCandidates[slasheeIdx].address,
            ]);

            expect(await roninValidatorSetContract.getValidators()).have.same.members([
              validatorCandidates[slasheeIdx].address,
            ]);
          });

          it('Should the ValidatorSet contract emit event', async () => {
            for (let i = 0; i < felonyThreshold - 1; i++) {
              await slashIndicatorContract.connect(coinbase).slash(validatorCandidates[slasheeIdx].address);
            }
            slashValidatorTx = await slashIndicatorContract
              .connect(coinbase)
              .slash(validatorCandidates[slasheeIdx].address);

            await expect(slashValidatorTx)
              .to.emit(slashIndicatorContract, 'ValidatorSlashed')
              .withArgs(validatorCandidates[slasheeIdx].address, SlashType.FELONY);

            let blockNumber = await network.provider.send('eth_blockNumber');

            await expect(slashValidatorTx)
              .to.emit(roninValidatorSetContract, 'ValidatorSlashed')
              .withArgs(
                validatorCandidates[slasheeIdx].address,
                BigNumber.from(blockNumber).add(felonyJailDuration),
                slashFelonyAmount
              );
          });

          it('Should the validator get subtracted staked amount', async () => {});

          it('Should the validator is put in jail', async () => {});

          it('Should the validator set exclude the jailed validator in the next epoch', async () => {});

          it('Should the validator candidate cannot join as a validator when jail time is over, due to insufficient fund', async () => {});

          it('Should the validator top-up balance and be able to re-join the validator set', async () => {});
        });
      });
    });
  });
});
