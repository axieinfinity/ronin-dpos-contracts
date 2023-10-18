// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import { MappedTokenConsumer } from "@ronin/contracts/interfaces/consumers/MappedTokenConsumer.sol";
import { console2, BaseDeploy, ContractKey, Network } from "../BaseDeploy.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_ETH is BaseDeploy, MappedTokenConsumer {
  RoninGovernanceAdmin internal _mainchainGovernanceAdmin;
  MainchainGatewayV3 internal _mainchainGatewayV3;
  MainchainBridgeManager internal _mainchainBridgeManager;

  function run() public virtual trySetUp {
    _mainchainGatewayV3 = MainchainGatewayV3(_config.getAddressFromCurrentNetwork(ContractKey.MainchainGatewayV3));
    _mainchainBridgeManager = MainchainBridgeManager(
      _config.getAddressFromCurrentNetwork(ContractKey.MainchainBridgeManager)
    );
    _mainchainGovernanceAdmin = RoninGovernanceAdmin(_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin));

    _upgradeProxy(
      ContractKey.MainchainGatewayV3,
      abi.encodeCall(MainchainGatewayV3.initializeV2, (address(_mainchainBridgeManager)))
    );
    vm.startPrank(address(_mainchainGovernanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(_mainchainGatewayV3))).changeAdmin(address(_mainchainBridgeManager));
    vm.stopPrank();
  }
}
