import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { ethers, network } from 'hardhat';
import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';

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

interface ProxyManagementInfo {
  deployment: Deployment | null;
  address?: Address;
  admin?: Address;
  expectedAdmin?: Address;
  isCorrect?: Boolean;
}

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

const getAdminOfProxy = async (address: Address): Promise<string> => {
  const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
  const slotValue = await ethers.provider.getStorageAt(address, ADMIN_SLOT);
  return ethers.utils.hexStripZeros(slotValue);
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

function isCorrectAdmin(admin: Address, expectedAdmin: Address): boolean {
  if (expectedAdmin == DEFAULT_ADDRESS) return false;
  return admin.toLocaleLowerCase() == expectedAdmin.toLocaleLowerCase();
}

// yarn hardhat deploy --tags QueryProxyAdminRonin --network ronin-testnet
deploy.tags = ['QueryProxyAdminRonin'];

export default deploy;
