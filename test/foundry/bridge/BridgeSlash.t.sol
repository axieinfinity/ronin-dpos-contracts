// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { LibArrayUtils } from "../helpers/LibArrayUtils.t.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { MockValidatorContract } from "@ronin/contracts/mocks/ronin/MockValidatorContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { IBridgeSlash, MockBridgeSlash, BridgeSlash } from "@ronin/contracts/mocks/ronin/MockBridgeSlash.sol";
import { IBridgeManager, BridgeManagerUtils } from "./utils/BridgeManagerUtils.t.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Math } from "@ronin/contracts/libraries/Math.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrProxyCallFailed, ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { IBridgeSlashEventsTest } from "./interfaces/IBridgeSlashEvents.t.sol";

contract BridgeSlashTest is IBridgeSlashEventsTest, BridgeManagerUtils {
  using ErrorHandler for bool;
  using LibArrayUtils for uint256[];

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

  function test_slashTierLogic(uint96 ballot, uint256 totalBallots, uint64 period, uint64 slashUntilPeriod) external {
    vm.assume(period != 0);
    vm.assume(totalBallots != 0 && ballot < totalBallots);

    IBridgeSlash bridgeSlashContract = IBridgeSlash(_bridgeSlashContract);
    IBridgeSlash.Tier tier = bridgeSlashContract.getSlashTier(ballot, totalBallots);
    uint256 newSlashUntilPeriod = MockBridgeSlash(payable(_bridgeSlashContract)).calcSlashUntilPeriod(
      tier,
      period,
      slashUntilPeriod
    );

    console.log(uint8(tier), period, slashUntilPeriod, newSlashUntilPeriod);

    if (tier == IBridgeSlash.Tier.Tier1) {
      if (period < slashUntilPeriod) {
        assertTrue(newSlashUntilPeriod == uint256(slashUntilPeriod) + bridgeSlashContract.TIER_1_PENALTY_DURATION());
      } else {
        assertTrue(newSlashUntilPeriod == period + bridgeSlashContract.TIER_1_PENALTY_DURATION() - 1);
      }
    } else if (tier == IBridgeSlash.Tier.Tier2) {
      if (period < slashUntilPeriod) {
        assertTrue(newSlashUntilPeriod == uint256(slashUntilPeriod) + bridgeSlashContract.TIER_2_PENALTY_DURATION());

        if (
          MockBridgeSlash(payable(_bridgeSlashContract)).isSlashDurationMetRemovalThreshold(newSlashUntilPeriod, period)
        ) {
          assertTrue(newSlashUntilPeriod - period + 1 >= bridgeSlashContract.REMOVE_DURATION_THRESHOLD());
        }
      } else {
        assertTrue(newSlashUntilPeriod == uint256(period) + bridgeSlashContract.TIER_2_PENALTY_DURATION() - 1);
      }
    }
  }

  function test_bridgeSlash_recordEvents_onBridgeOperatorsAdded(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators,
    uint256 period
  ) external {
    vm.assume(r1 != DEFAULT_R1 && r2 != DEFAULT_R2 && r3 != DEFAULT_R3);

    period = _bound(period, 1, type(uint64).max);

    MockValidatorContract(payable(_validatorContract)).setCurrentPeriod(period);
    address[] memory registers = new address[](1);
    registers[0] = _bridgeSlashContract;
    MockBridgeManager(payable(_bridgeManagerContract)).registerCallbacks(registers);

    (address[] memory bridgeOperators, address[] memory governors, uint256[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    vm.expectEmit(_bridgeSlashContract);
    emit NewBridgeOperatorsAdded(period, bridgeOperators);

    _addBridgeOperators(_bridgeManagerContract, _bridgeManagerContract, voteWeights, governors, bridgeOperators);

    uint256[] memory addedPeriods = IBridgeSlash(_bridgeSlashContract).getAddedPeriodOf(bridgeOperators);
    for (uint256 i; i < addedPeriods.length; ) {
      assertEq(addedPeriods[i], period);
      unchecked {
        ++i;
      }
    }
  }

  function test_ExcludeNewlyAddedOperators_ExecSlashBridgeOperators(
    uint256 r1,
    uint256 period,
    uint256 duration
  ) external {
    period = _bound(period, 1, type(uint64).max);
    duration = _bound(duration, MIN_PERIOD_DURATION, MAX_PERIOD_DURATION);

    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    vm.startPrank(_bridgeTrackingContract, _bridgeTrackingContract);
    uint256[] memory ballots;
    uint256 totalBallotsForPeriod;
    IBridgeSlash bridgeSlashContract = IBridgeSlash(_bridgeSlashContract);
    for (uint256 i; i < duration; ) {
      ballots = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);
      totalBallotsForPeriod = ballots.sum();

      bridgeSlashContract.execSlashBridgeOperators(bridgeOperators, ballots, totalBallotsForPeriod, period);

      r1 = uint256(keccak256(abi.encode(r1)));

      unchecked {
        ++period;
        ++i;
      }
    }
    vm.stopPrank();
  }

  function test_Valid_ExecSlashBridgeOperators(uint256 r1, uint256 period, uint256 duration) external {
    period = _bound(period, 1, type(uint64).max);
    duration = _bound(duration, MIN_PERIOD_DURATION, MAX_PERIOD_DURATION);

    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    vm.startPrank(_bridgeTrackingContract, _bridgeTrackingContract);
    uint256[] memory ballots;
    uint256 totalBallotsForPeriod;
    IBridgeSlash bridgeSlashContract = IBridgeSlash(_bridgeSlashContract);
    for (uint256 i; i < duration; ) {
      ballots = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);
      totalBallotsForPeriod = ballots.sum();

      bridgeSlashContract.execSlashBridgeOperators(bridgeOperators, ballots, totalBallotsForPeriod, period);

      r1 = uint256(keccak256(abi.encode(r1)));

      unchecked {
        ++period;
        ++i;
      }
    }
    vm.stopPrank();
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

    _bridgeSlashLogic = address(new MockBridgeSlash());
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
