import { expect } from 'chai';
import { network, ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  Staking,
  Staking__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo__factory,
  MockRoninValidatorSetEpochSetterAndQueryInfo,
  TransparentUpgradeableProxy__factory,
} from '../../src/types';
import { Network, slashIndicatorConf, roninValidatorSetConf, stakingConfig, initAddress } from '../../src/config';
import { BigNumber } from 'ethers';

let slashContract: SlashIndicator;
let stakingContract: Staking;
let validatorContract: MockRoninValidatorSetEpochSetterAndQueryInfo;

let coinbase: SignerWithAddress;
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

describe('[Integration] Submit Block Reward', () => {
  before(async () => {
    [coinbase, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
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
    slashContract = SlashIndicator__factory.connect(slashProxyContract.address, deployer);

    validatorContract = await new MockRoninValidatorSetEpochSetterAndQueryInfo__factory(deployer).deploy(
      governanceAdmin.address,
      slashContract.address,
      stakingContractAddr,
      maxValidatorNumber
    );
    await validatorContract.deployed();

    const stakingLogicContract = await new Staking__factory(deployer).deploy();
    await stakingLogicContract.deployed();

    const stakingProxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      stakingLogicContract.address,
      proxyAdmin.address,
      stakingLogicContract.interface.encodeFunctionData('initialize', [
        validatorContract.address,
        governanceAdmin.address,
        100,
        minValidatorBalance,
      ])
    );
    await stakingProxyContract.deployed();
    stakingContract = Staking__factory.connect(stakingProxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase()).eq(validatorContract.address.toLowerCase());
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  describe('Configuration check', async () => {
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
  });
});
