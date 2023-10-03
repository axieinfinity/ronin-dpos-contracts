// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2, BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { ConditionalImplementControl } from "@ronin/contracts/extensions/version-control/ConditionalImplementControl.sol";

contract NotifiedMigratorUpgrade is BaseDeploy {
  function run(ContractKey contractKey, bytes[] calldata callDatas) public virtual trySetUp returns (address payable) {
    address payable proxy = _config.getAddressFromCurrentNetwork(contractKey);
    address proxyAdmin = _getProxyAdmin(proxy);
    address prevImpl = _getProxyImplementation(proxy);
    address newImpl = _deployLogic(contractKey, EMPTY_ARGS);
    address notifier = _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet);
    address switcher = _deployImmutable(ContractKey.NotifiedMigrator, abi.encode(proxy, prevImpl, newImpl, notifier));
    console2.log("notifier", notifier);
    return _upgradeRaw(proxyAdmin, proxy, switcher, abi.encodeCall(ConditionalImplementControl.setCallDatas, (callDatas)));
  }
}
