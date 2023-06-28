import { expect } from 'chai';
import { companionNetworks, deployments, ethers, network } from 'hardhat';

import {
  BridgeTracking,
  BridgeTracking__factory,
  RoninValidatorSet,
  RoninValidatorSet__factory,
} from '../../src/types';
import { BigNumber, BigNumberish } from 'ethers';
import { lazyObject } from 'hardhat/plugins';
import { HardhatRuntimeEnvironment, Network } from 'hardhat/types';
import * as hardhatDeploy from 'hardhat-deploy';
import { Address } from 'hardhat-deploy/dist/types';

let bridgeTracking: BridgeTracking;
let validatorSet: RoninValidatorSet;

let __before__operators: Address[] = [];
let __after__operators: Address[] = [];
let __before__period: BigNumberish;
let __after__period: BigNumberish;

describe('Testnet Fork: Migration test', () => {
  before(async () => {
    const BridgeTrackingProxy = await deployments.get('BridgeTrackingProxy');
    const RoninValidatorSetProxy = await deployments.get('RoninValidatorSetProxy');
    bridgeTracking = BridgeTracking__factory.connect(BridgeTrackingProxy.address, ethers.provider);
    validatorSet = RoninValidatorSet__factory.connect(RoninValidatorSetProxy.address, ethers.provider);
  });

  it('before upgrade', async () => {
    [__before__operators] = await validatorSet.getBridgeOperators();
    __before__period = await validatorSet.currentPeriod();
  });

  it('upgrade', async () => {
    await deployments.fixture([
      'MaintenanceLogic',
      'StakingVestingLogic',
      'SlashIndicatorLogic',
      'StakingLogic',
      'RoninValidatorSetLogic',
      'RoninTrustedOrganizationLogic',
      'BridgeTrackingLogic',
      'MainchainGatewayV2Logic',
      'RoninGatewayV2Logic',
      '230627UpgradeTestnetV0_5_2',
    ]);
  });

  it('after upgrade', async () => {
    [__before__operators] = await validatorSet.getBridgeOperators();
    expect(__before__operators).eqls(__after__operators);
    expect(__before__period).eq(__after__period);
  });
});
