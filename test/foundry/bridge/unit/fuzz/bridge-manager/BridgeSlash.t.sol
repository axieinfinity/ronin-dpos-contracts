// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { LibArrayUtils } from "@ronin/test/helpers/LibArrayUtils.t.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { MockValidatorContract } from "@ronin/contracts/mocks/ronin/MockValidatorContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { IBridgeSlash, MockBridgeSlash, BridgeSlash } from "@ronin/contracts/mocks/ronin/MockBridgeSlash.sol";
import { IBridgeManager, BridgeManagerUtils } from "../utils/BridgeManagerUtils.t.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Math } from "@ronin/contracts/libraries/Math.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrProxyCallFailed, ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { IBridgeSlashEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeSlashEvents.sol";

contract BridgeSlashTest is IBridgeSlashEvents, BridgeManagerUtils {
  using ErrorHandler for bool;
  using LibArrayUtils for *;
  using AddressArrayUtils for *;

  uint256 internal constant MIN_PERIOD_DURATION = 1;
  uint256 internal constant MAX_PERIOD_DURATION = 20;

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

  /**
   * @notice Tests the fuzz slash tier logic by simulating the slash calculation for a given ballot and total ballots.
   * @dev This function is for testing purposes only.
   * @param ballot The number of ballots for the specific bridge operator.
   * @param totalVote The total number of votes for the period.
   * @param period The current period.
   * @param slashUntilPeriod The slash until period for the bridge operator.
   */
  function test_Fuzz_SlashTierLogic(uint96 ballot, uint96 totalVote, uint64 period, uint64 slashUntilPeriod) external {
    // Assume period is not zero and totalVote is not zero, and ballot is less than totalVote
    vm.assume(period != 0);
    vm.assume(totalVote >= IBridgeSlash(_bridgeSlashContract).MINIMUM_VOTE_THRESHOLD() && ballot < totalVote);

    // Get the bridge slash contract and determine the slash tier
    IBridgeSlash bridgeSlashContract = IBridgeSlash(_bridgeSlashContract);
    IBridgeSlash.Tier tier = bridgeSlashContract.getSlashTier(ballot, totalVote);
    // Calculate the new slash until period using the mock bridge slash contract
    uint256 newSlashUntilPeriod = MockBridgeSlash(payable(_bridgeSlashContract)).calcSlashUntilPeriod(
      tier,
      period,
      slashUntilPeriod
    );

    // Log the tier and slash period information
    console.log("tier", "period", "slashUntilPeriod", "newSlashUntilPeriod");
    console.log(uint8(tier), period, slashUntilPeriod, newSlashUntilPeriod);

    if (tier == Tier.Tier1) {
      // Check the slash duration for Tier 1
      if (period <= slashUntilPeriod) {
        assertTrue(newSlashUntilPeriod == uint256(slashUntilPeriod) + bridgeSlashContract.TIER_1_PENALTY_DURATION());
      } else {
        assertTrue(newSlashUntilPeriod == period + bridgeSlashContract.TIER_1_PENALTY_DURATION() - 1);
      }
    } else if (tier == Tier.Tier2) {
      // Check the slash duration for Tier 2
      if (period <= slashUntilPeriod) {
        assertTrue(newSlashUntilPeriod == uint256(slashUntilPeriod) + bridgeSlashContract.TIER_2_PENALTY_DURATION());

        // Check if the slash duration meets the removal threshold
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

  /**
   * @notice Tests the recording of events when bridge operators are added.
   * @dev This function is for testing purposes only.
   * @param r1 1st Random value for generating valid inputs.
   * @param r2 2nd Random value for generating valid inputs.
   * @param r3 3rd Random value for generating valid inputs.
   * @param numBridgeOperators The number of bridge operators to add.
   * @param period The current period.
   */
  function test_bridgeSlash_recordEvents_onBridgeOperatorsAdded(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators,
    uint256 period
  ) external {
    address[] memory currentOperators = IBridgeManager(_bridgeManagerContract).getBridgeOperators();
    vm.prank(_bridgeManagerContract, _bridgeManagerContract);
    IBridgeManager(_bridgeManagerContract).removeBridgeOperators(currentOperators);
    // Assume the input values are not equal to the default values
    vm.assume(r1 != DEFAULT_R1 && r2 != DEFAULT_R2 && r3 != DEFAULT_R3);
    // Bound the period between 1 and the maximum value of uint64
    period = _bound(period, 1, type(uint64).max);

    // Set the current period in the mock validator contract
    MockValidatorContract(payable(_validatorContract)).setCurrentPeriod(period);

    // Register the bridge slash contract as a callback
    vm.prank(_bridgeManagerContract, _bridgeManagerContract);
    address[] memory registers = new address[](1);
    registers[0] = _bridgeSlashContract;
    MockBridgeManager(payable(_bridgeManagerContract)).registerCallbacks(registers);

    // Generate valid inputs for bridge operators
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    _addBridgeOperators(_bridgeManagerContract, _bridgeManagerContract, voteWeights, governors, bridgeOperators);

    // Retrieve the added periods for the bridge operators
    uint256[] memory addedPeriods = IBridgeSlash(_bridgeSlashContract).getAddedPeriodOf(bridgeOperators);
    // Check that the added periods match the current period
    for (uint256 i; i < addedPeriods.length; ) {
      assertEq(addedPeriods[i], period);
      unchecked {
        ++i;
      }
    }
  }

  /*
   * @notice Tests the exclusion of newly added operators during the execution of slashBridgeOperators.
   * @param 1st Random value for generating valid inputs.
   * @param period The initial period.
   * @param duration The duration of the test.
   * @param newlyAddedSize The number of newly added operators.
   */
  function test_ExcludeNewlyAddedOperators_ExecSlashBridgeOperators(
    uint256 r1,
    uint256 period,
    uint256 duration,
    uint256 newlyAddedSize
  ) external {
    vm.assume(r1 != 0);
    vm.assume(r1 != DEFAULT_R1 && r1 != DEFAULT_R2 && r1 != DEFAULT_R3);
    // Bound the period, duration, and newlyAddedSize values
    period = _bound(period, 1, type(uint64).max);
    duration = _bound(duration, MIN_PERIOD_DURATION, MAX_PERIOD_DURATION);
    newlyAddedSize = _bound(newlyAddedSize, MIN_FUZZ_INPUTS, MAX_FUZZ_INPUTS);

    // Register the bridge slash contract as a callback in the bridge manager contract
    address[] memory registers = new address[](1);
    registers[0] = _bridgeSlashContract;
    vm.prank(_bridgeManagerContract, _bridgeManagerContract);
    MockBridgeManager(payable(_bridgeManagerContract)).registerCallbacks(registers);

    // Decode the default bridge manager inputs to retrieve bridge operators
    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    for (uint256 i; i < duration; ) {
      // Set the current period in the mock validator contract
      MockValidatorContract(payable(_validatorContract)).setCurrentPeriod(period);
      // Generate valid inputs for newly added operators
      uint256[] memory newlyAddedAtPeriods;
      address[] memory newlyAddedOperators;
      {
        address[] memory newlyAddedGovernors;
        uint96[] memory newlyAddedWeights;
        (newlyAddedOperators, newlyAddedGovernors, newlyAddedWeights) = getValidInputs(
          r1,
          ~r1,
          r1 << 1,
          newlyAddedSize
        );

        // Add the newly added operators using the bridge manager contract
        vm.prank(_bridgeManagerContract, _bridgeManagerContract);
        bool[] memory addeds = IBridgeManager(_bridgeManagerContract).addBridgeOperators(
          newlyAddedWeights,
          newlyAddedGovernors,
          newlyAddedOperators
        );
        vm.assume(addeds.sum() == addeds.length);
        // Retrieve the added periods for the newly added operators
        newlyAddedAtPeriods = IBridgeSlash(_bridgeSlashContract).getAddedPeriodOf(newlyAddedOperators);
      }

      // Generate random ballots for bridge operators and newly added operators
      uint256[] memory ballots = _createRandomNumbers(r1, bridgeOperators.length + newlyAddedSize, 0, MAX_FUZZ_INPUTS);
      // Execute slashBridgeOperators for all operators
      vm.prank(_bridgeTrackingContract, _bridgeTrackingContract);
      IBridgeSlash(_bridgeSlashContract).execSlashBridgeOperators(
        bridgeOperators.extend(newlyAddedOperators),
        ballots,
        ballots.sum(),
        ballots.sum(),
        period
      );

      // Check that the slashUntilPeriods and newlyAddedAtPeriods are correctly set
      uint256 length = newlyAddedAtPeriods.length;
      uint256[] memory slashUntilPeriods = IBridgeSlash(_bridgeSlashContract).getSlashUntilPeriodOf(
        newlyAddedOperators
      );
      for (uint256 j; j < length; ) {
        assertEq(slashUntilPeriods[j], 0);
        assertEq(newlyAddedAtPeriods[j], period);
        unchecked {
          ++j;
        }
      }

      // Generate the next random number for r1
      r1 = uint256(keccak256(abi.encode(r1)));

      unchecked {
        ++period;
        ++i;
      }
    }
  }

  /*
   * @notice Tests the execution of `execSlashBridgeOperators` function with valid inputs.
   * @param Random value for generating random numbers.
   * @param period The initial period.
   * @param duration The duration of the test.
   */
  function test_Valid_ExecSlashBridgeOperators(uint256 r1, uint256 period, uint256 duration) external {
    // Bound the period and duration values
    period = _bound(period, 1, type(uint64).max);
    duration = _bound(duration, MIN_PERIOD_DURATION, MAX_PERIOD_DURATION);

    // Decode the default bridge manager inputs to retrieve bridge operators
    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    vm.startPrank(_bridgeTrackingContract, _bridgeTrackingContract);
    uint256[] memory ballots;
    uint256 totalBallotForPeriod;
    IBridgeSlash bridgeSlashContract = IBridgeSlash(_bridgeSlashContract);
    MockValidatorContract validatorContract = MockValidatorContract(payable(_validatorContract));
    for (uint256 i; i < duration; ) {
      // Generate random ballots for bridge operators
      ballots = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);
      totalBallotForPeriod = ballots.sum();

      // Set the current period in the mock validator contract
      validatorContract.setCurrentPeriod(period);

      // Execute the `execSlashBridgeOperators` function
      bridgeSlashContract.execSlashBridgeOperators(
        bridgeOperators,
        ballots,
        totalBallotForPeriod,
        totalBallotForPeriod,
        period
      );

      // Generate the next random number for r1 using the keccak256 hash function
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
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      DEFAULT_R1,
      DEFAULT_R2,
      DEFAULT_R3,
      DEFAULT_NUM_BRIDGE_OPERATORS
    );
    _defaultBridgeManagerInputs = abi.encode(bridgeOperators, governors, voteWeights);
    _bridgeManagerContract = address(new MockBridgeManager(bridgeOperators, governors, voteWeights));

    _gatewayLogic = address(new RoninGatewayV3());
    _gatewayContract = address(new TransparentUpgradeableProxyV2(_gatewayLogic, _admin, ""));

    _bridgeTrackingLogic = address(new BridgeTracking());
    _bridgeTrackingContract = address(
      new TransparentUpgradeableProxyV2(_bridgeTrackingLogic, _bridgeManagerContract, "")
    );

    _bridgeSlashLogic = address(new MockBridgeSlash());
    _bridgeSlashContract = address(
      new TransparentUpgradeableProxyV2(
        _bridgeSlashLogic,
        _bridgeManagerContract,
        abi.encodeCall(BridgeSlash.initialize, (_validatorContract, _bridgeManagerContract, _bridgeTrackingContract, address(0)))
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
