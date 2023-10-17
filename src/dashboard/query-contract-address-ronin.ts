import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { ContractManagementInfo, getContractAddress } from './dashboard-helper';

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
const AllContractTypes = {
  UNKNOWN: 0,
  PAUSE_ENFORCER: 1,
  BRIDGE: 2,
  BRIDGE_TRACKING: 3,
  GOVERNANCE_ADMIN: 4,
  MAINTENANCE: 5,
  SLASH_INDICATOR: 6,
  STAKING_VESTING: 7,
  VALIDATOR: 8,
  STAKING: 9,
  RONIN_TRUSTED_ORGANIZATION: 10,
  BRIDGE_MANAGER: 11,
  BRIDGE_SLASH: 12,
  BRIDGE_REWARD: 13,
  FAST_FINALITY_TRACKING: 14,
  PROFILE: 15,
} as const;
const ProxyNames = { ...DPoSProxyName } as const;

type KeyOf<T> = keyof T;
type ValueOf<T> = T[KeyOf<T>];
type ProxyNamesType = KeyOf<typeof ProxyNames>;
type ContractNameType = KeyOf<typeof AllContractTypes>;
type CombineProxyAndContractType = `${ProxyNamesType}:${ContractNameType}`;

interface ContractManagementInfoComponents {
  [deploymentName: CombineProxyAndContractType | string]: ContractManagementInfo;
}

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const BridgeManagerDeployment = await deployments.get('RoninBridgeManager');
  const GovernanceAdminDeployment = await deployments.get('RoninGovernanceAdmin');

  console.log('BridgeManager', BridgeManagerDeployment.address);
  console.log('GovernanceAdmin', GovernanceAdminDeployment.address);

  let components: ContractManagementInfoComponents = {};

  console.log({ AllContractTypes });
  for (const proxyName of Object.keys(ProxyNames)) {
    for (const contractTypeKey of Object.keys(AllContractTypes)) {
      const key: CombineProxyAndContractType | string = `${proxyName}:${contractTypeKey}`;
      const deployment = await deployments.getOrNull(getValueByKey(proxyName as ProxyNamesType, ProxyNames));
      let address = deployment?.address;

      if (
        getValueByKey(proxyName as ProxyNamesType, ProxyNames).toLocaleLowerCase() ==
        BridgeProxyName.BridgeContract.toLocaleLowerCase()
      ) {
        address = address ?? generalRoninConf[network.name].bridgeContract;
        console.info('Loaded BridgeContract from config.');
      }

      if (!address) {
        continue;
      }
      const contract = await getContractAddress(
        address,
        getValueByKey(contractTypeKey as ContractNameType, AllContractTypes)
      );
      components[key] = {
        deployment,
        address,
        proxyName,
        contractType: contractTypeKey,
        contractAddr: contract,
        //   admin,
        //   expectedAdmin,
        //   isCorrect: isCorrectAdmin(admin, expectedAdmin),
      };
    }
    console.table(components, [
      'address',
      'proxyName',
      'contractType',
      'contractAddr',
      'expectContractAddr',
      'isCorrect',
    ]);
  }
};

function getValueByKey<T extends Object>(key: KeyOf<T>, object: T): ValueOf<T> {
  return object[key];
}

// yarn hardhat deploy --tags QueryHasAddressRonin --network ronin-testnet
deploy.tags = ['QueryHasAddressRonin'];

export default deploy;
