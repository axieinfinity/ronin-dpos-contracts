import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  MockPrecompile,
  MockPrecompile__factory,
  MockSlashIndicatorExtended,
  RoninGovernanceAdmin,
  RoninTrustedOrganization,
  MockRoninValidatorSetExtended__factory,
  MockSlashIndicatorExtended__factory,
  RoninTrustedOrganization__factory,
  RoninGovernanceAdmin__factory,
  MockRoninValidatorSetExtended,
  MockPrecompileUsagePickValidatorSet__factory,
  MockPrecompileUsagePickValidatorSet,
} from '../../src/types';
import { Network } from '../../src/utils';
import { Address } from 'hardhat-deploy/dist/types';
import { BigNumber } from 'ethers';
import { initTest } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../src/script/governance-admin-interface';

let validatorContract: MockRoninValidatorSetExtended;
let slashIndicator: MockSlashIndicatorExtended;
let roninTrustedOrganization: RoninTrustedOrganization;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let deployer: SignerWithAddress;
let governor: SignerWithAddress;
let cdds: Address[];
let mockPrecompile: MockPrecompile;
let usagePickValidator: MockPrecompileUsagePickValidatorSet;

const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 7;
const maxPrioritizedValidatorNumber = 4;
const maxValidatorCandidate = 100;
const defaultTrustedWeight = BigNumber.from(100);

describe('[Precompile Integration] Pick validator set test', function (this: Mocha.Suite) {
  const suite = this;

  before(async () => {
    [deployer, governor] = await ethers.getSigners();
    cdds = Array.from({ length: maxValidatorCandidate }, (_, i) =>
      ethers.utils.hexZeroPad(ethers.utils.hexlify(i + 0x40), 20)
    );

    const {
      slashContractAddress,
      validatorContractAddress,
      roninTrustedOrganizationAddress,
      roninGovernanceAdminAddress,
    } = await initTest('PrecompileIntegrationPickValidatorSet')({
      slashIndicatorArguments: {
        unavailabilitySlashing: {
          slashAmountForUnavailabilityTier2Threshold,
        },
      },
      roninValidatorSetArguments: {
        maxValidatorCandidate,
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: [governor].map((v) => ({
          consensusAddr: v.address,
          governor: v.address,
          bridgeVoter: v.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
    });
    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    roninTrustedOrganization = RoninTrustedOrganization__factory.connect(roninTrustedOrganizationAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(governanceAdmin, governor);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);

    if (network.name != Network.Devnet) {
      console.log(
        '\x1b[35m ',
        `> Deployed mock precompiled due to current network is not "${Network.Devnet}". Current network: "${network.name}".`
      );

      mockPrecompile = await new MockPrecompile__factory(deployer).deploy();
      usagePickValidator = await new MockPrecompileUsagePickValidatorSet__factory(deployer).deploy(
        mockPrecompile.address
      );
    } else {
      console.log('\x1b[35m ', `> Skipped deploying mock precompiled due to current network is "${Network.Devnet}".`);
    }
  });

  describe('Config test', async () => {
    it('Should the usage contract correctly configs the precompile address', async () => {
      expect(await usagePickValidator.precompilePickValidatorSetAddress()).eq(mockPrecompile.address);
    });

    it('Should the usage contract revert with proper message on calling the precompile contract fails', async () => {
      await usagePickValidator.setPrecompilePickValidatorSetAddress(ethers.constants.AddressZero);

      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      await expect(
        usagePickValidator.callPrecompile(
          _candidates,
          _weights,
          _trustedWeights,
          _maxValidatorNumber,
          _maxPrioritizedValidatorNumber
        )
      ).revertedWith('PrecompileUsagePickValidatorSet: call to precompile fails');
    });

    after(async () => {
      await usagePickValidator.setPrecompilePickValidatorSetAddress(mockPrecompile.address);
    });
  });

  describe('Pick validator set test', async () => {
    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[1], cdds[0], cdds[7], cdds[6], cdds[5]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });

    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 9);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900, 1000];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[1], cdds[0], cdds[8], cdds[7], cdds[6]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
    it('Actual(prioritized) == MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 7);
      let _weights = [200, 300, 400, 500, 600, 700, 800];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[1], cdds[0], cdds[6], cdds[5]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });

    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 7;
      let _maxPrioritizedValidatorNumber = 4;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[1], cdds[7], cdds[6], cdds[5]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 5;
      let _maxPrioritizedValidatorNumber = 4;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[1], cdds[7]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
    it('Actual(prioritized) >  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 3;

      let _expectingValidatorAddr = [cdds[4], cdds[3], cdds[2], cdds[7], cdds[6], cdds[5], cdds[1], cdds[0]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });

    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) == MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 7);
      let _weights = [200, 300, 400, 500, 600, 700, 800];
      let _trustedWeights = [1, 1, 1, 1, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[3], cdds[2], cdds[1], cdds[0], cdds[6], cdds[5], cdds[4]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) >  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 0, 0, 0, 0];
      let _maxValidatorNumber = 8;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[3], cdds[2], cdds[1], cdds[0], cdds[7], cdds[6], cdds[5], cdds[4]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
    it('Actual(prioritized) <  MaxNum(prioritized); Actual(regular) <  MaxNum(regular)', async () => {
      let _candidates = cdds.slice(0, 8);
      let _weights = [200, 300, 400, 500, 600, 700, 800, 900];
      let _trustedWeights = [1, 1, 1, 1, 0, 0, 0, 0];
      let _maxValidatorNumber = 10;
      let _maxPrioritizedValidatorNumber = 5;

      let _expectingValidatorAddr = [cdds[3], cdds[2], cdds[1], cdds[0], cdds[7], cdds[6], cdds[5], cdds[4]];

      let _outputValidators = await usagePickValidator.callPrecompile(
        _candidates,
        _weights,
        _trustedWeights,
        _maxValidatorNumber,
        _maxPrioritizedValidatorNumber
      );
      expect(_outputValidators).eql(_expectingValidatorAddr);
    });
  });
});
