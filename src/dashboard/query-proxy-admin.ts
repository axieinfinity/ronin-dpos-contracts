import { EthereumProvider, HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgrades/upgradeUtils';
import {
  MainchainGatewayV2__factory,
  RoninValidatorSetTimedMigrator__factory,
  RoninValidatorSet__factory,
} from '../types';
import { generalMainchainConf, generalRoninConf, roninchainNetworks } from '../configs/config';
import { ethers, network } from 'hardhat';
import { Address, Deployment } from 'hardhat-deploy/dist/types';
import type * as ethersType from 'ethers';

const BridgeProxyName = {
  BridgeReward: 'BridgeRewardProxy',
  BridgeSlash: 'BridgeSlashProxy',
  BridgeTracking: 'BridgeTrackingProxy',
  bridgeContract: 'RoninGatewayProxyV2',
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
  correctAdmin?: Boolean;
}

interface ProxyManagementInfoRecords {
  [deploymentName: ProxyNamesType | string]: ProxyManagementInfo;
}

const deploy = async ({ deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const BridgeManagerDeployment = await deployments.get('RoninBridgeManager');
  const GovernanceAdminDeployment = await deployments.get('RoninGovernanceAdmin');

  console.log('BridgeManager', BridgeManagerDeployment.address);
  console.log('GovernanceAdmin', GovernanceAdminDeployment.address);

  const records: ProxyManagementInfoRecords = {};
  for (const key of Object.keys(ProxyNames)) {
    const deployment = await deployments.getOrNull(getValueByKey(key as ProxyNamesType));
    const address = deployment ? deployment.address : generalRoninConf[network.name].bridgeContract; // TODO: handle load bridgeContract from config file

    const admin = await getAdminOfProxy(ethers.provider, address);
    records[key] = {
      deployment,
      address,
      admin,
      correctAdmin:
        Object.keys(BridgeProxyName).indexOf(key) != -1
          ? admin.toLocaleLowerCase() == BridgeManagerDeployment.address.toLocaleLowerCase()
          : admin.toLocaleLowerCase() == GovernanceAdminDeployment.address.toLocaleLowerCase(),
    };
  }

  console.table(records);
};

const getAdminOfProxy = async (provider: ethersType.providers.JsonRpcProvider, address: Address): Promise<string> => {
  const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
  const slotValue = await ethers.provider.getStorageAt(address, ADMIN_SLOT);
  return ethers.utils.hexStripZeros(slotValue);
};

function getValueByKey(key: ProxyNamesType): string {
  const indexOfS = Object.keys(ProxyNames).indexOf(key);
  return Object.values(ProxyNames)[indexOfS];
}

// yarn hardhat deploy --tags QueryProxyAdmin --network ronin-testnet
deploy.tags = ['QueryProxyAdmin'];

export default deploy;
