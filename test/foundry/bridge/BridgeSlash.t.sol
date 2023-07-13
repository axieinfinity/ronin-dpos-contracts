// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { IBridgeSlash, BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { IBridgeManager, BridgeManagerUtils } from "./utils/BridgeManagerUtils.t.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrProxyCallFailed, ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { IBridgeSlashEventsTest } from "./interfaces/IBridgeSlashEvents.t.sol";

contract BridgeSlashTest is IBridgeSlashEventsTest, BridgeManagerUtils {
  using ErrorHandler for bool;

  // @dev label for making address
  string internal constant ADMIN = "ADMIN";
  string internal constant GATEWAY = "GATEWAY";
  string internal constant VALIDATOR = "VALIDATOR";
  string internal constant BRIDGE_SLASH = "BRIDGE_SLASH";
  string internal constant BRIDGE_MANAGER = "BRIDGE_MANAGER";
  string internal constant BRIDGE_TRACKING = "BRIDGE_TRACKING";

  /// @dev immutable contracts
  address internal _admin;
  address internal _validatorContract;
  address internal _bridgeManagerContract;
  /// @dev proxy contracts
  address internal _gatewayContract;
  address internal _bridgeSlashContract;
  address internal _bridgeTrackingContract;

  bytes internal _initBridgeManagerInputs;

  function setUp() external {
    _setUp();
  }

  function _setUp() internal virtual {
    _admin = makeAddr(ADMIN);

    // immutable contracts
    _validatorContract = makeAddr(VALIDATOR);
    _bridgeManagerContract = makeAddr(BRIDGE_MANAGER);

    // proxy contracts
    _gatewayContract = makeAddr(GATEWAY);
    _bridgeSlashContract = makeAddr(BRIDGE_SLASH);
    _bridgeTrackingContract = makeAddr(BRIDGE_TRACKING);

    (, bytes memory bridgeManagerInputs) = address(this).staticcall(
      abi.encodeCall(this.getValidInputs, (DEFAULT_R1, DEFAULT_R2, DEFAULT_R3, DEFAULT_NUM_BRIDGE_OPERATORS))
    );
    _initBridgeManagerInputs = bridgeManagerInputs;
    _initImmutable(_bridgeManagerContract, "MockBridgeManager.sol", bridgeManagerInputs);

    _initProxy(_gatewayContract, GATEWAY, _admin, type(RoninGatewayV2).creationCode, "");
    _initProxy(
      _bridgeSlashContract,
      BRIDGE_SLASH,
      _admin,
      type(BridgeSlash).creationCode,
      abi.encodeCall(BridgeSlash.initialize, (_validatorContract, _bridgeManagerContract, _bridgeTrackingContract))
    );
    _initProxy(_bridgeTrackingContract, BRIDGE_TRACKING, _admin, type(BridgeTracking).creationCode, "");
  }

  function test_Valid_ExecSlashBridgeOperators(uint256 r1, uint256 period) external {
    vm.assume(period != 0);

    (address[] memory allBridgeOperators, , ) = abi.decode(_initBridgeManagerInputs, (address[], address[], uint256[]));

    uint256[] memory ballots = _createRandomNumbers(r1, allBridgeOperators.length, 0, MAX_FUZZ_INPUTS);
    uint256 totalBallotsForPeriod;
    for (uint256 i; i < ballots.length; ) {
      totalBallotsForPeriod += ballots[i];
      unchecked {
        ++i;
      }
    }

    vm.prank(_bridgeTrackingContract, _bridgeTrackingContract);
    IBridgeSlash(_bridgeSlashContract).execSlashBridgeOperators(
      allBridgeOperators,
      ballots,
      totalBallotsForPeriod,
      period
    );
  }

  function _initImmutable(address to, string memory contractPath, bytes memory args) internal {
    deployCodeTo(contractPath, args, to);
  }

  function _initProxy(
    address proxy,
    string memory label,
    address admin,
    bytes memory logicBytecode,
    bytes memory args
  ) internal {
    address logic = makeAddr(string(abi.encodePacked(label, "_LOGIC")));
    vm.etch(logic, logicBytecode);
    deployCodeTo("TransparentUpgradeableProxyV2.sol", abi.encode(logic, admin, args), proxy);
  }
}
