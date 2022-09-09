import { expect } from 'chai';
import { network, ethers, deployments } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  RoninValidatorSet__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Network, slashIndicatorConf, roninValidatorSetConf, stakingConfig, initAddress } from '../../src/config';
import { BigNumber, ContractTransaction } from 'ethers';
import { SlashType } from '../slash/slashType';
import { expects as RoninValidatorSetExpects } from '../../src/script/ronin-validator-set';
import { mineBatchTxs } from '../utils';

let slashIndicatorContract: SlashIndicator;
let stakingContract: Staking;
let roninValidatorSetContract: MockRoninValidatorSetEpochSetterAndQueryInfo;

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

describe('[Integration] Slash validators', () => {
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

    roninValidatorSetContract = await new MockRoninValidatorSetEpochSetterAndQueryInfo__factory(deployer).deploy(
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

  describe('Configuration test', async () => {
    it('Should the SlashContract config the ValidatorSetContract correctly', async () => {
      let _validatorContract = await slashIndicatorContract.validatorContract();
      expect(_validatorContract).to.eq(roninValidatorSetContract.address);
    });

    it('Should the ValidatorSetContract config the SlashContract correctly', async () => {
      let _slashContract = await roninValidatorSetContract.slashIndicatorContract();
      expect(_slashContract).to.eq(slashIndicatorContract.address);
    });

    it('Should the ValidatorSetContract config the StakingContract correctly', async () => {
      let _stakingContract = await roninValidatorSetContract.stakingContract();
      expect(_stakingContract).to.eq(stakingContract.address);
    });
  });

  describe('Slash on one validator', async () => {
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

      describe("Slash felony validator -- when the validator' balance is sufficient after being slashed", async () => {
        let slasheeIdx = 2;
        let updateValidatorTx: ContractTransaction;
        let slashValidatorTx: ContractTransaction;

        before(async () => {
          await stakingContract
            .connect(validatorCandidates[slasheeIdx])
            .proposeValidator(validatorCandidates[slasheeIdx].address, validatorCandidates[slasheeIdx].address, 2_00, {
              value: minValidatorBalance.add(slashFelonyAmount.mul(10)),
            });

          await mineBatchTxs(async () => {
            await roninValidatorSetContract.connect(coinbase).endEpoch();
            updateValidatorTx = await roninValidatorSetContract.connect(coinbase).wrapUpEpoch();
          });
          await RoninValidatorSetExpects.emitValidatorSetUpdatedEvent(updateValidatorTx!, [
            validatorCandidates[slasheeIdx].address,
          ]);

          expect(await roninValidatorSetContract.getValidators()).eql([validatorCandidates[slasheeIdx].address]);
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

        it('Should the validator is put in jail', async () => {
          let blockNumber = await network.provider.send('eth_blockNumber');
          expect(await roninValidatorSetContract.getJailUntils([validatorCandidates[slasheeIdx].address])).eql([
            BigNumber.from(blockNumber).add(felonyJailDuration),
          ]);
        });

        it('Should the validator get subtracted staked amount', async () => {});

        it('Should the validator set exclude the jailed validator in the next epoch', async () => {});

        it('Should the validator candidate cannot join as a validator when jail time is over, due to insufficient fund', async () => {});

        it('Should the validator top-up balance and be able to re-join the validator set', async () => {});
      });

      describe.skip("Slash felony validator -- when the validator's balance is equal to minimum balance", async () => {});
    });
  });
});
