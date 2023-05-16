/// npx hardhat deploy --tags 230516SetNewEnforcerMainchainGateway --network ronin-mainnet

/// This script does the following:
/// - Set new enforcer for mainchain gateway

/// Governor who proposes this proposal must manually vote it after running this script.

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { GatewayV2__factory } from '../types';
import { proxyCall } from './upgradeUtils';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const newMainchainPauseEnforcerLogic = ''; // TODO: Should input new pause enforcer here
  const mainchainGatewayProxy = await deployments.get('MainchainGatewayV2Proxy');

  /// Set new enforcer for gateway
  const GatewayInterface = GatewayV2__factory.createInterface();
  const gatewayInstructions = [
    proxyCall(GatewayInterface.encodeFunctionData('setEmergencyPauser', [newMainchainPauseEnforcerLogic])),
  ];

  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days
  const proposalChainId = 1;

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'propose',

    // function propose(
    //   uint256 _chainId,
    //   uint256 _expiryTimestamp,
    //   address[] calldata _targets,
    //   uint256[] calldata _values,
    //   bytes[] calldata _calldatas,
    //   uint256[] calldata _gasAmounts
    // )

    proposalChainId,
    proposalExpiryTimestamp, // expiryTimestamp
    gatewayInstructions.map(() => mainchainGatewayProxy.address), // targets
    gatewayInstructions.map(() => 0), // values
    gatewayInstructions, // datas
    gatewayInstructions.map(() => 1_000_000) // gasAmounts
  );

  console.log(`https://explorer.roninchain.com/tx/${tx.transactionHash}`);
};

deploy.tags = ['230516SetNewEnforcerMainchainGateway'];

export default deploy;
