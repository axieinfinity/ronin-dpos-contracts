import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { getContractAddress, isCorrectContract } from './dashboard-helper';

const BridgeProxyName = {
  BridgeReward: 'BridgeRewardProxy',
  BridgeSlash: 'BridgeSlashProxy',
  BridgeTracking: 'BridgeTrackingProxy',
  BridgeContract: 'RoninGatewayProxyV2',
  BridgeManager: 'RoninBridgeManager',
} as const;

const DPoSProxyName = {
  Maintenance: 'MaintenanceProxy',
  RoninGatewayPauseEnforcer: 'RoninGatewayPauseEnforcerProxy',
  RoninTrustedOrganization: 'RoninTrustedOrganizationProxy',
  RoninValidatorSet: 'RoninValidatorSetProxy',
  SlashIndicator: 'SlashIndicatorProxy',
  Staking: 'StakingProxy',
  StakingVesting: 'StakingVestingProxy',
  GovernanceAdmin: 'RoninGovernanceAdmin',
  FastFinalityTracking: 'FastFinalityTrackingProxy',
} as const;

const AllContractTypes: MappingFromContractTypeToProxyName = {
  UNKNOWN: {
    value: 0,
  },
  PAUSE_ENFORCER: {
    value: 1,
  },
  BRIDGE: {
    value: 2,
    proxyName: 'BridgeContract',
  },
  BRIDGE_TRACKING: {
    value: 3,
    proxyName: 'BridgeTracking',
  },
  GOVERNANCE_ADMIN: {
    value: 4,
    proxyName: 'GovernanceAdmin',
  },
  MAINTENANCE: {
    value: 5,
    proxyName: 'Maintenance',
  },
  SLASH_INDICATOR: {
    value: 6,
    proxyName: 'SlashIndicator',
  },
  STAKING_VESTING: {
    value: 7,
    proxyName: 'StakingVesting',
  },
  VALIDATOR: {
    value: 8,
    proxyName: 'RoninValidatorSet',
  },
  STAKING: {
    value: 9,
    proxyName: 'Staking',
  },
  RONIN_TRUSTED_ORGANIZATION: {
    value: 10,
    proxyName: 'RoninTrustedOrganization',
  },
  BRIDGE_MANAGER: {
    value: 11,
    proxyName: 'BridgeManager',
  },
  BRIDGE_SLASH: {
    value: 12,
    proxyName: 'BridgeSlash',
  },
  BRIDGE_REWARD: {
    value: 13,
    proxyName: 'BridgeReward',
  },
  FAST_FINALITY_TRACKING: {
    value: 14,
    proxyName: 'FastFinalityTracking',
  },
  PROFILE: {
    value: 15,
  },
} as const;
const ProxyNames = { ...DPoSProxyName, ...BridgeProxyName } as const;

type KeyOf<T> = keyof T;
type ProxyNamesKey = KeyOf<typeof ProxyNames>;
type ContractTypeKey = KeyOf<typeof AllContractTypes>;
type CombineProxyAndContractType = `${ProxyNamesKey}:${ContractTypeKey}`;

export interface ContractManagementInfo {
  address?: Address;
  proxyName?: ProxyNamesKey;
  contractType?: ContractTypeKey;
  contractAddr?: Address;
  expectedContractAddr?: Address;
  isCorrect?: Boolean;
}

interface ContractManagementInfoComponents {
  [deploymentName: CombineProxyAndContractType | string]: ContractManagementInfo;
}

interface MappingFromContractTypeToProxyName {
  [contractType: string]: {
    proxyName?: ProxyNamesKey;
    value: number;
  };
}
interface MappingFromProxyNameToAddress {
  [proxyName: ProxyNamesKey | string]: Address;
}

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }
  const allContractTypeKeys = Object.keys(AllContractTypes).map((key) => key as ContractTypeKey);
  const allProxyNameKeys = Object.keys(ProxyNames).map((key) => key as ProxyNamesKey);

  const preLoadContractAddresses: MappingFromProxyNameToAddress = {};
  let components: ContractManagementInfoComponents = {};

  // load all addresses
  for (const proxyNameKey of allProxyNameKeys) {
    const deployment = await deployments.getOrNull(ProxyNames[proxyNameKey]);
    let address = deployment?.address;
    if (ProxyNames[proxyNameKey] == BridgeProxyName.BridgeContract) {
      address = address ?? generalRoninConf[network.name].bridgeContract;
      console.info('Loaded BridgeContract from config.');
    }

    if (!address) {
      continue;
    }
    preLoadContractAddresses[proxyNameKey] = address;
  }

  for (const proxyNameKey of allProxyNameKeys) {
    const address = preLoadContractAddresses[proxyNameKey];
    for (const contractTypeKey of allContractTypeKeys) {
      const key = `${proxyNameKey}:${contractTypeKey}` as CombineProxyAndContractType;
      const data = AllContractTypes[contractTypeKey.toString()];
      const contractAddr = await getContractAddress(address, data.value);
      const expectedContractAddr = data.proxyName ? preLoadContractAddresses[data.proxyName] : DEFAULT_ADDRESS;
      components[key] = {
        address: address,
        proxyName: proxyNameKey,
        contractType: contractTypeKey,
        contractAddr,
        expectedContractAddr,
        isCorrect: isCorrectContract(contractAddr, expectedContractAddr),
      };
    }
    console.table(components, [
      'address',
      'proxyName',
      'contractType',
      'contractAddr',
      'expectedContractAddr',
      'isCorrect',
    ]);
    components = {};
  }
};

// yarn hardhat deploy --tags QueryHasAddressRonin --network ronin-testnet
deploy.tags = ['QueryHasAddressRonin'];

export default deploy;
