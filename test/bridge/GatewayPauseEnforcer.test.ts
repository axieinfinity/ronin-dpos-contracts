import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';
import {
  BridgeTracking,
  BridgeTracking__factory,
  ERC20PresetMinterPauser__factory,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  MockRoninGatewayV2Extended,
  MockRoninGatewayV2Extended__factory,
  RoninGovernanceAdmin,
  RoninGovernanceAdmin__factory,
  Staking,
  Staking__factory,
  TransparentUpgradeableProxyV2__factory,
  PauseEnforcer,
  PauseEnforcer__factory,
} from '../../src/types';
import { ERC20PresetMinterPauser } from '../../src/types/ERC20PresetMinterPauser';
import { ReceiptStruct } from '../../src/types/IRoninGatewayV2';
import { DEFAULT_ADDRESS, DEFAULT_ADMIN_ROLE, SENTRY_ROLE } from '../../src/utils';
import {
  createManyTrustedOrganizationAddressSets,
  createManyValidatorCandidateAddressSets,
  TrustedOrganizationAddressSet,
  ValidatorCandidateAddressSet,
} from '../helpers/address-set-types';
import { initTest } from '../helpers/fixture';
import { getRoles, mineBatchTxs } from '../helpers/utils';

let deployer: SignerWithAddress;
let coinbase: SignerWithAddress;
let enforcerAdmin: SignerWithAddress;
let enforcerSentry: SignerWithAddress;
let trustedOrgs: TrustedOrganizationAddressSet[];
let candidates: ValidatorCandidateAddressSet[];
let signers: SignerWithAddress[];

let bridgeContract: MockRoninGatewayV2Extended;
let bridgeTracking: BridgeTracking;
let stakingContract: Staking;
let roninValidatorSet: MockRoninValidatorSetExtended;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;
let token: ERC20PresetMinterPauser;

let pauseEnforcer: PauseEnforcer;

let period: BigNumberish;
let receipts: ReceiptStruct[];

const maxValidatorNumber = 6;
const maxPrioritizedValidatorNumber = maxValidatorNumber - 2;
const minValidatorStakingAmount = 500;

// only requires 3 operator for the proposal to pass
const numerator = 3;
const denominator = maxValidatorNumber;

// requires 1 trusted operators for the proposal to pass
const trustedNumerator = 1;
const trustedDenominator = maxPrioritizedValidatorNumber;

const mainchainId = 1;
const numberOfBlocksInEpoch = 600;

describe('Ronin Gateway V2 test', () => {
  before(async () => {
    [deployer, coinbase, enforcerAdmin, enforcerSentry, ...signers] = await ethers.getSigners();
    // Set up that all candidates except the 2 last ones are trusted org
    candidates = createManyValidatorCandidateAddressSets(signers.splice(0, maxValidatorNumber * 3));
    trustedOrgs = createManyTrustedOrganizationAddressSets(
      candidates.slice(0, maxPrioritizedValidatorNumber).map((_) => _.consensusAddr),
      signers.splice(0, maxPrioritizedValidatorNumber),
      signers.splice(0, maxPrioritizedValidatorNumber)
    );

    // Deploys bridge contracts
    token = await new ERC20PresetMinterPauser__factory(deployer).deploy('ERC20', 'ERC20');
    const logic = await new MockRoninGatewayV2Extended__factory(deployer).deploy();
    const proxy = await new TransparentUpgradeableProxyV2__factory(deployer).deploy(
      logic.address,
      deployer.address,
      logic.interface.encodeFunctionData('initialize', [
        ethers.constants.AddressZero,
        numerator,
        denominator,
        trustedNumerator,
        trustedDenominator,
        [],
        [[token.address], [token.address]],
        [[mainchainId], [0]],
        [0],
      ])
    );
    bridgeContract = MockRoninGatewayV2Extended__factory.connect(proxy.address, deployer);
    await token.grantRole(await token.MINTER_ROLE(), bridgeContract.address);

    // Deploys pauser
    pauseEnforcer = await new PauseEnforcer__factory(deployer).deploy(
      bridgeContract.address, // target
      enforcerAdmin.address, // admin
      [enforcerSentry.address] // sentry
    );

    // Deploys DPoS contracts
    const {
      bridgeTrackingAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      roninTrustedOrganizationAddress,
      validatorContractAddress,
    } = await initTest('RoninGatewayV2-PauseEnforcer')({
      bridgeContract: bridgeContract.address,
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          bridgeVoter: v.bridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
        numerator,
        denominator,
      },
      stakingArguments: {
        minValidatorStakingAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
        numberOfBlocksInEpoch,
      },
    });

    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    roninValidatorSet = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    bridgeTracking = BridgeTracking__factory.connect(bridgeTrackingAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(roninValidatorSet.address, mockValidatorLogic.address);
    await roninValidatorSet.initEpoch();

    await TransparentUpgradeableProxyV2__factory.connect(proxy.address, deployer).changeAdmin(governanceAdmin.address);
    await governanceAdminInterface.functionDelegateCalls(
      Array.from(Array(3).keys()).map(() => bridgeContract.address),
      [
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRoles('BRIDGE_TRACKING_CONTRACT'),
          bridgeTracking.address,
        ]),
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRoles('VALIDATOR_CONTRACT'),
          roninValidatorSet.address,
        ]),
        bridgeContract.interface.encodeFunctionData('setContract', [
          getRoles('RONIN_TRUSTED_ORGANIZATION_CONTRACT'),
          roninTrustedOrganizationAddress,
        ]),
      ]
    );

    // Applies candidates and double check the bridge operators
    for (let i = 0; i < candidates.length; i++) {
      await stakingContract
        .connect(candidates[i].poolAdmin)
        .applyValidatorCandidate(
          candidates[i].candidateAdmin.address,
          candidates[i].consensusAddr.address,
          candidates[i].treasuryAddr.address,
          candidates[i].bridgeOperator.address,
          1,
          { value: minValidatorStakingAmount + candidates.length - i }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    period = await roninValidatorSet.currentPeriod();
    expect((await roninValidatorSet.getBridgeOperators())._bridgeOperatorList).deep.equal(
      candidates.map((v) => v.bridgeOperator.address)
    );
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [DEFAULT_ADDRESS]);
  });

  describe('Set up emergency pauser contract', () => {
    it('Should be able to call set up emergency pauser contract in the gateway', async () => {
      await governanceAdminInterface.functionDelegateCalls(
        [bridgeContract.address],
        [bridgeContract.interface.encodeFunctionData('setEmergencyPauser', [pauseEnforcer.address])]
      );
    });

    it('Should the gateway set up pauser correctly', async () => {
      expect(await bridgeContract.emergencyPauser()).eq(pauseEnforcer.address);
    });

    it('Should the pauser set up config correctly', async () => {
      expect(await pauseEnforcer.target()).eq(bridgeContract.address);
      expect(await pauseEnforcer.hasRole(SENTRY_ROLE, enforcerSentry.address)).eq(true);
    });
  });

  describe('Emergency pause & emergency unpause', () => {
    it('Should be able to emergency pause', async () => {
      expect(await pauseEnforcer.connect(enforcerSentry).triggerPause())
        .emit(pauseEnforcer, 'EmergencyPaused')
        .withArgs(enforcerSentry.address);

      expect(await pauseEnforcer.emergency()).eq(true);
      expect(await bridgeContract.paused()).eq(true);
    });

    it('Should the gateway cannot interacted when on pause', async () => {
      receipts = [
        {
          id: 0,
          kind: 0,
          mainchain: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: mainchainId,
          },
          ronin: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: network.config.chainId!,
          },
          info: { erc: 0, id: 0, quantity: 100 },
        },
      ];
      receipts.push({ ...receipts[0], id: 1 });

      await expect(bridgeContract.connect(candidates[0].bridgeOperator).tryBulkDepositFor(receipts)).revertedWith(
        'Pausable: paused'
      );
    });

    it('Should not be able to emergency pause for a second time', async () => {
      await expect(pauseEnforcer.connect(enforcerSentry).triggerPause()).revertedWithCustomError(
        pauseEnforcer,
        'ErrTargetIsNotOnPaused'
      );
    });

    it('Should be able to emergency unpause', async () => {
      expect(await pauseEnforcer.connect(enforcerSentry).triggerUnpause())
        .emit(pauseEnforcer, 'EmergencyUnpaused')
        .withArgs(enforcerSentry.address);

      expect(await pauseEnforcer.emergency()).eq(false);
      expect(await bridgeContract.paused()).eq(false);
    });

    it('Should the gateway can be interacted after unpause', async () => {
      receipts = [
        {
          id: 0,
          kind: 0,
          mainchain: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: mainchainId,
          },
          ronin: {
            addr: deployer.address,
            tokenAddr: token.address,
            chainId: network.config.chainId!,
          },
          info: { erc: 0, id: 0, quantity: 100 },
        },
      ];
      receipts.push({ ...receipts[0], id: 1 });

      for (let i = 0; i < numerator - 1; i++) {
        const tx = await bridgeContract.connect(candidates[i].bridgeOperator).tryBulkDepositFor(receipts);
        await expect(tx).not.emit(bridgeContract, 'Deposited');
      }
    });
  });

  describe('Normal pause & emergency unpause', () => {
    it('Should gateway admin can pause the gateway through voting', async () => {
      let tx = await governanceAdminInterface.functionDelegateCalls(
        [bridgeContract.address],
        [bridgeContract.interface.encodeFunctionData('pause')]
      );

      expect(tx).emit(bridgeContract, 'Paused').withArgs(governanceAdmin.address);
      expect(await pauseEnforcer.emergency()).eq(false);
      expect(await bridgeContract.paused()).eq(true);
    });

    it('Should not be able to emergency unpause', async () => {
      await expect(pauseEnforcer.connect(enforcerSentry).triggerUnpause()).revertedWithCustomError(
        pauseEnforcer,
        'ErrNotOnEmergencyPause'
      );
    });

    it('Should not be able to override by emergency pause and emergency unpause', async () => {
      await expect(pauseEnforcer.connect(enforcerSentry).triggerPause()).revertedWithCustomError(
        pauseEnforcer,
        'ErrTargetIsNotOnPaused'
      );
      await expect(pauseEnforcer.connect(enforcerSentry).triggerUnpause()).revertedWithCustomError(
        pauseEnforcer,
        'ErrNotOnEmergencyPause'
      );
    });

    it('Should gateway admin can unpause the gateway through voting', async () => {
      let tx = await governanceAdminInterface.functionDelegateCalls(
        [bridgeContract.address],
        [bridgeContract.interface.encodeFunctionData('unpause')]
      );

      expect(tx).emit(bridgeContract, 'Unpaused').withArgs(governanceAdmin.address);
      expect(await pauseEnforcer.emergency()).eq(false);
      expect(await bridgeContract.paused()).eq(false);
    });
  });

  describe('Access control', () => {
    it('Should admin of pause enforcer can be change', async () => {
      let newEnforcerAdmin = signers[0];
      await pauseEnforcer.connect(enforcerAdmin).grantRole(DEFAULT_ADMIN_ROLE, newEnforcerAdmin.address);
      expect(await pauseEnforcer.hasRole(DEFAULT_ADMIN_ROLE, newEnforcerAdmin.address)).eq(true);
    });

    it('Should previous admin of pause enforcer can be revoked', async () => {
      expect(await pauseEnforcer.hasRole(DEFAULT_ADMIN_ROLE, enforcerAdmin.address)).eq(true);
      await pauseEnforcer.connect(enforcerAdmin).renounceRole(DEFAULT_ADMIN_ROLE, enforcerAdmin.address);
      expect(await pauseEnforcer.hasRole(DEFAULT_ADMIN_ROLE, enforcerAdmin.address)).eq(false);
    });
  });
});
