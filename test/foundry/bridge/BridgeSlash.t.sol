// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { MockValidatorContract } from "@ronin/contracts/mocks/ronin/MockValidatorContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { IBridgeSlash, BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { IBridgeManager, BridgeManagerUtils } from "./utils/BridgeManagerUtils.t.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrProxyCallFailed, ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { IBridgeSlashEventsTest } from "./interfaces/IBridgeSlashEvents.t.sol";

contract BridgeSlashTest is IBridgeSlashEventsTest, BridgeManagerUtils {
  using ErrorHandler for bool;

  uint256 internal constant MIN_PERIOD_DURATION = 1;
  uint256 internal constant MAX_PERIOD_DURATION = 365;

  /// @dev immutable contracts
  address internal _admin;
  address internal _validatorContract;
  address internal _bridgeManagerContract;
  /// @dev proxy contracts
  address internal _gatewayLogic;
  address internal _gatewayContract;
  address internal _bridgeSlashLogic;
  address internal _bridgeSlashContract;
  address internal _bridgeTrackingLogic;
  address internal _bridgeTrackingContract;

  bytes internal _defaultBridgeManagerInputs;

  function setUp() external {
    _setUp();
    _label();
  }

  function test_Valid_ExecSlashBridgeOperators(uint256 r1, uint256 period, uint256 duration) external {
    period = _bound(period, 1, type(uint64).max);
    duration = _bound(duration, MIN_PERIOD_DURATION, MAX_PERIOD_DURATION);

    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    for (uint256 i; i < duration; ) {
      uint256[] memory ballots = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);

      uint256 totalBallotsForPeriod;
      for (uint256 j; j < ballots.length; ) {
        totalBallotsForPeriod += ballots[j];
        unchecked {
          ++j;
        }
      }

      vm.prank(_bridgeTrackingContract, _bridgeTrackingContract);
      IBridgeSlash(_bridgeSlashContract).execSlashBridgeOperators(
        bridgeOperators,
        ballots,
        totalBallotsForPeriod,
        period
      );

      r1 = uint256(keccak256(abi.encode(r1)));

      unchecked {
        ++period;
        ++i;
      }
    }
  }

  function _setUp() internal virtual {
    _admin = vm.addr(1);
    _validatorContract = address(new MockValidatorContract());
    (address[] memory bridgeOperators, address[] memory governors, uint256[] memory voteWeights) = getValidInputs(
      DEFAULT_R1,
      DEFAULT_R2,
      DEFAULT_R3,
      DEFAULT_NUM_BRIDGE_OPERATORS
    );
    _defaultBridgeManagerInputs = abi.encode(bridgeOperators, governors, voteWeights);
    _bridgeManagerContract = address(new MockBridgeManager(bridgeOperators, governors, voteWeights));

    _gatewayLogic = address(new RoninGatewayV2());
    _gatewayContract = address(new TransparentUpgradeableProxy(_gatewayLogic, _admin, ""));

    _bridgeTrackingLogic = address(new BridgeTracking());
    _bridgeTrackingContract = address(new TransparentUpgradeableProxy(_bridgeTrackingLogic, _admin, ""));

    _bridgeSlashLogic = address(new BridgeSlash());
    _bridgeSlashContract = address(
      new TransparentUpgradeableProxy(
        _bridgeSlashLogic,
        _admin,
        abi.encodeCall(BridgeSlash.initialize, (_validatorContract, _bridgeManagerContract, _bridgeTrackingContract))
      )
    );
  }

  function _label() internal virtual {
    vm.label(_admin, "ADMIN");
    vm.label(_validatorContract, "VALIDATOR");
    vm.label(_bridgeManagerContract, "BRIDGE_MANAGER");
    vm.label(_gatewayLogic, "GATEWAY_LOGIC");
    vm.label(_gatewayContract, "GATEWAY");
    vm.label(_bridgeTrackingLogic, "BRIDGE_TRACKING_LOGIC");
    vm.label(_bridgeTrackingContract, "BRIDGE_TRACKING");
    vm.label(_bridgeSlashLogic, "BRIDGE_SLASH_LOGIC");
    vm.label(_bridgeSlashContract, "BRIDGE_SLASH");
  }
}
