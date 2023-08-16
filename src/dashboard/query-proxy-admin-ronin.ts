import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { ProxyManagementInfo, getAdminOfProxy, isCorrectAdmin } from './dashboard-helper';

const BridgeProxyName = {
  BridgeReward: 'BridgeRewardProxy',
  BridgeSlash: 'BridgeSlashProxy',
  BridgeTracking: 'BridgeTrackingProxy',
  BridgeContract: 'RoninGatewayProxyV2',
} as const;

const DPoSProxyName = {
  Maintenance: 'MaintenanceProxy',
  RoninGatewayPauseEnforcer: 'RoninGatewayPauseEnforcerProxy',
  RoninTrustedOrganization: 'RoninTrustedOrganizationProxy',
  RoninValidatorSet: 'RoninValidatorSetProxy',
  SlashIndicator: 'SlashIndicatorProxy',
  Staking: 'StakingProxy',
  StakingVesting: 'StakingVestingProxy',
} as const;

const ProxyNames = { ...BridgeProxyName, ...DPoSProxyName } as const;

type ValueOf<T> = T[keyof T];
type ProxyNamesType = ValueOf<typeof ProxyNames>;

interface ProxyManagementInfoComponents {
  [deploymentName: ProxyNamesType | string]: ProxyManagementInfo;
}

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const BridgeManagerDeployment = await deployments.get('RoninBridgeManager');
  const GovernanceAdminDeployment = await deployments.get('RoninGovernanceAdmin');

  console.log('BridgeManager', BridgeManagerDeployment.address);
  console.log('GovernanceAdmin', GovernanceAdminDeployment.address);

  const components: ProxyManagementInfoComponents = {};
  for (const key of Object.keys(ProxyNames)) {
    const deployment = await deployments.getOrNull(getValueByKey(key as ProxyNamesType));
    let address = deployment?.address;

    if (getValueByKey(key as ProxyNamesType) == BridgeProxyName.BridgeContract) {
      address = address ?? generalRoninConf[network.name].bridgeContract;
      console.info('Loaded BridgeContract from config.');
    }

    if (!address) {
      continue;
    }

    const admin = await getAdminOfProxy(address);
    const expectedAdmin = getExpectedAdmin(key, BridgeManagerDeployment.address, GovernanceAdminDeployment.address);
    components[key] = {
      deployment,
      address,
      admin,
      expectedAdmin,
      isCorrect: isCorrectAdmin(admin, expectedAdmin),
    };
  }

  console.table(components, ['address', 'admin', 'expectedAdmin', 'isCorrect']);
};

function getValueByKey(key: ProxyNamesType): string {
  const indexOfS = Object.keys(ProxyNames).indexOf(key);
  return Object.values(ProxyNames)[indexOfS];
}

function getExpectedAdmin(key: string, bridgeAdmin: Address, governanceAdmin: Address): Address {
  return Object.keys(BridgeProxyName).indexOf(key) != -1
    ? bridgeAdmin
    : Object.keys(DPoSProxyName).indexOf(key) != -1
    ? governanceAdmin
    : DEFAULT_ADDRESS;
}

// yarn hardhat deploy --tags QueryProxyAdminRonin --network ronin-testnet
deploy.tags = ['QueryProxyAdminRonin'];

export default deploy;
