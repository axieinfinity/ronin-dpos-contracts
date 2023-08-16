import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { generalMainchainConf, mainchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { ProxyManagementInfo, getAdminOfProxy, isCorrectAdmin } from './dashboard-helper';

const BridgeProxyName = {
  BridgeContract: 'MainchainGatewayProxyV2',
} as const;

const ProxyNames = { ...BridgeProxyName } as const;

type ValueOf<T> = T[keyof T];
type ProxyNamesType = ValueOf<typeof ProxyNames>;

interface ProxyManagementInfoComponents {
  [deploymentName: ProxyNamesType | string]: ProxyManagementInfo;
}

const deploy = async ({ deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const BridgeManagerDeployment = await deployments.get('MainchainBridgeManager');
  console.log('BridgeManager', BridgeManagerDeployment.address);

  const components: ProxyManagementInfoComponents = {};
  for (const key of Object.keys(ProxyNames)) {
    const deployment = await deployments.getOrNull(getValueByKey(key as ProxyNamesType));
    let address = deployment?.address;

    if (getValueByKey(key as ProxyNamesType) == BridgeProxyName.BridgeContract) {
      address = address ?? generalMainchainConf[network.name].bridgeContract;
      console.info('Loaded BridgeContract from config.');
    }

    if (!address) {
      continue;
    }

    const admin = await getAdminOfProxy(address);
    const expectedAdmin = BridgeManagerDeployment.address;
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

// yarn hardhat deploy --tags QueryProxyAdminMainchain --network goerli
deploy.tags = ['QueryProxyAdminMainchain'];

export default deploy;
