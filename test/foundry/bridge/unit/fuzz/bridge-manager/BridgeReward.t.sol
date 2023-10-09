// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Base_Test } from "@ronin/test/Base.t.sol";
import { LibArrayUtils } from "@ronin/test/helpers/LibArrayUtils.t.sol";
import { IBridgeRewardEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeRewardEvents.sol";
import { IBridgeManager, BridgeManagerUtils } from "../utils/BridgeManagerUtils.t.sol";
import { MockValidatorContract } from "@ronin/contracts/mocks/ronin/MockValidatorContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { IBridgeSlash, MockBridgeSlash, BridgeSlash } from "@ronin/contracts/mocks/ronin/MockBridgeSlash.sol";
import { IBridgeReward, MockBridgeReward, BridgeReward } from "@ronin/contracts/mocks/ronin/MockBridgeReward.sol";

contract BridgeRewardTest is Base_Test, IBridgeRewardEvents, BridgeManagerUtils {
  using LibArrayUtils for uint256[];

  uint256 internal constant DEFAULT_REWARD_PER_PERIOD = 1 ether;

  address internal _admin;
  address internal _validatorContract;
  address internal _bridgeRewardLogic;
  address internal _bridgeManagerContract;
  address internal _bridgeRewardContract;
  address internal _bridgeSlashLogic;
  address internal _bridgeSlashContract;
  address internal _bridgeTrackingContract;
  address internal _bridgeTrackingLogic;

  bytes internal _defaultBridgeManagerInputs;

  function setUp() external {
    _setUp();
    _label();
  }

  /**
   * @notice Test the fuzz reward calculation logic.
   * @param r1 Random number for generating slashUntils.
   * @param r2 Random number for generating ballots.
   * @param totalVote Total number of votes.
   * @param period The period being tested.
   */
  function test_Fuzz_RewardCalculationLogic(uint256 r1, uint256 r2, uint256 totalVote, uint256 period) external {
    // Ensure r1 and r2 are not equal
    vm.assume(r1 != r2);

    // Bound the period within the valid range
    period = _bound(period, 1, type(uint64).max);

    // Decode the default bridge manager inputs
    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    // Generate random numbers for slashUntils and ballots
    uint256[] memory slashUntils = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);
    uint256[] memory ballots = _createRandomNumbers(r2, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);

    // Get the bridge reward contract instance
    MockBridgeReward bridgeRewardContract = MockBridgeReward(payable(_bridgeRewardContract));

    // Calculate the total number of ballots
    uint256 totalBallot = ballots.sum();
    // Determine if the reward should be shared equally among bridge operators
    bool shouldShareEqually = bridgeRewardContract.shouldShareEqually(totalBallot, totalVote, ballots);

    // Get the reward per period from the bridge reward contract
    uint256 rewardPerPeriod = IBridgeReward(_bridgeRewardContract).getRewardPerPeriod();

    // Assert the reward calculation based on the sharing method
    if (shouldShareEqually) {
      _assertCalculateRewardEqually(shouldShareEqually, rewardPerPeriod, totalBallot, bridgeRewardContract, ballots);
    } else {
      _assertCalculateRewardProportionally(
        shouldShareEqually,
        rewardPerPeriod,
        totalBallot,
        bridgeRewardContract,
        ballots
      );
    }
    // Assert the slashing of bridge operators for the given period
    _assertSlashBridgeOperators(period, slashUntils, bridgeRewardContract);
  }

  /**
   * @notice Test the scenario when the total number of ballots is zero and the bridge tracking response is not valid.
   * @dev This function is for internal testing purposes only.
   * @param totalVote Total number of votes.
   */
  function test_WhenTotalBallotsZero_NotValidBridgeTrackingResponse(uint256 totalVote) external {
    // Get the bridge reward contract instance
    MockBridgeReward bridgeRewardContract = MockBridgeReward(payable(_bridgeRewardContract));

    // Decode the default bridge manager inputs
    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));
    // Create an empty array for ballots
    uint256[] memory ballots = new uint256[](bridgeOperators.length);
    // Calculate the total number of ballots
    uint256 totalBallot = ballots.sum();

    // Check if the bridge tracking response is valid and if the reward should be shared equally
    bool isValidResponse = bridgeRewardContract.isValidBridgeTrackingResponse(totalBallot, totalVote, ballots);
    bool shouldShareEqually = bridgeRewardContract.shouldShareEqually(totalBallot, totalVote, ballots);

    // Assert that the bridge tracking response is not valid and the reward is shared equally
    assertTrue(isValidResponse);
    assertTrue(shouldShareEqually);
  }

  /**
   * @notice Asserts the calculation of rewards proportionally.
   * @param isShareEqually Flag indicating whether rewards are shared equally.
   * @param rewardPerPeriod The total reward amount per period.
   * @param totalBallot The total number of ballots.
   * @param bridgeRewardContract The mock bridge reward contract.
   * @param ballots The array of ballots for bridge operators.
   */
  function _assertCalculateRewardProportionally(
    bool isShareEqually,
    uint256 rewardPerPeriod,
    uint256 totalBallot,
    MockBridgeReward bridgeRewardContract,
    uint256[] memory ballots
  ) internal {
    // Assert that rewards are not shared equally
    assertFalse(isShareEqually);

    uint256 length = ballots.length;
    uint256 actual;
    uint256 expected;

    for (uint256 i; i < length; ) {
      console.log("actual", actual);
      console.log("expected", expected);

      // Calculate the actual and expected rewards
      actual = bridgeRewardContract.calcReward(isShareEqually, length, rewardPerPeriod, ballots[i], totalBallot);
      expected = (rewardPerPeriod * ballots[i]) / totalBallot;

      // Assert that the actual and expected rewards are equal
      assertTrue(actual == expected);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Asserts the calculation of rewards when shared equally.
   * @param shouldShareEqually Flag indicating whether rewards are shared equally.
   * @param rewardPerPeriod The total reward amount per period.
   * @param totalBallot The total number of ballots.
   * @param bridgeRewardContract The mock bridge reward contract.
   * @param ballots The array of ballots for bridge operators.
   */
  function _assertCalculateRewardEqually(
    bool shouldShareEqually,
    uint256 rewardPerPeriod,
    uint256 totalBallot,
    MockBridgeReward bridgeRewardContract,
    uint256[] memory ballots
  ) internal {
    // Assert that rewards are shared equally
    assertTrue(shouldShareEqually);
    uint256 actual;
    uint256 length = ballots.length;
    uint256 expected = rewardPerPeriod / length;

    for (uint256 i; i < length; ) {
      console.log("actual", actual);
      console.log("expected", expected);

      // Calculate the actual and expected rewards
      actual = bridgeRewardContract.calcReward(shouldShareEqually, length, rewardPerPeriod, ballots[i], totalBallot);
      // Assert that the actual reward is equal to the expected reward
      assertTrue(actual == expected);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Asserts the slashing of bridge operators for a given period.
   * @param period The period being tested.
   * @param slashUntils The array of slash until periods for bridge operators.
   * @param bridgeRewardContract The mock bridge reward contract.
   */
  function _assertSlashBridgeOperators(
    uint256 period,
    uint256[] memory slashUntils,
    MockBridgeReward bridgeRewardContract
  ) internal {
    uint256 length = slashUntils.length;
    for (uint256 i; i < length; ) {
      // Check if the bridge operator is slashed for the current period
      if (period <= slashUntils[i]) {
        // Assert that the bridge operator is slashed for the current period
        assertTrue(bridgeRewardContract.shouldSlashedThisPeriod(period, slashUntils[i]));
      }

      unchecked {
        ++i;
      }
    }
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

    _bridgeTrackingLogic = address(new BridgeTracking());
    _bridgeTrackingContract = address(new TransparentUpgradeableProxy(_bridgeTrackingLogic, _admin, ""));

    _bridgeSlashLogic = address(new MockBridgeSlash());
    _bridgeSlashContract = address(
      new TransparentUpgradeableProxy(
        _bridgeSlashLogic,
        _admin,
        abi.encodeCall(BridgeSlash.initialize, (_validatorContract, _bridgeManagerContract, _bridgeTrackingContract, address(0)))
      )
    );

    _bridgeRewardLogic = address(new MockBridgeReward());
    _bridgeRewardContract = address(
      new TransparentUpgradeableProxy(
        _bridgeRewardLogic,
        _admin,
        abi.encodeCall(
          BridgeReward.initialize,
          (
            _bridgeManagerContract,
            _bridgeTrackingContract,
            _bridgeSlashContract,
            _validatorContract,
            address(0),
            DEFAULT_REWARD_PER_PERIOD
          )
        )
      )
    );
  }

  function _label() internal virtual {
    vm.label(_admin, "ADMIN");
    vm.label(_validatorContract, "VALIDATOR");
    vm.label(_bridgeManagerContract, "BRIDGE_MANAGER");
    vm.label(_bridgeTrackingLogic, "BRIDGE_TRACKING_LOGIC");
    vm.label(_bridgeTrackingContract, "BRIDGE_TRACKING");
    vm.label(_bridgeSlashLogic, "BRIDGE_SLASH_LOGIC");
    vm.label(_bridgeSlashContract, "BRIDGE_SLASH");
    vm.label(_bridgeRewardLogic, "BRIDGE_REWARD_LOGIC");
    vm.label(_bridgeRewardContract, "BRIDGE_REWARD_CONTRACT");
  }
}
