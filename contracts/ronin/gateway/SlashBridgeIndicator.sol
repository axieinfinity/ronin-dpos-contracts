// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeSlashing } from "../../interfaces/IBridgeSlashing.sol";
import { IBridgeManager } from "../../interfaces/IBridgeManager.sol";
import { IBridgeManagerCallback } from "../../interfaces/IBridgeManagerCallback.sol";
import { IBridgeTracking } from "../../interfaces/IBridgeTracking.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { ContractType } from "../../utils/ContractType.sol";

/**
 * @title SlashBridgeIndicator
 * @dev A contract that implements slashing functionality for bridge operators based on their availability.
 */
contract SlashBridgeIndicator is IBridgeSlashing, IBridgeManagerCallback, Initializable, HasContracts {
  /// @inheritdoc IBridgeSlashing
  uint256 public constant TIER_1_PENALIZE_DURATION = 1 days;
  /// @inheritdoc IBridgeSlashing
  uint256 public constant TIER_2_PENALIZE_DURATION = 5 days;
  /// @inheritdoc IBridgeSlashing
  uint256 public constant REMOVE_DURATION_THRESHOLD = 30 days;

  /// @dev Tier 1 slashing threshold ratio is 10%
  uint256 private constant TIER_1_THRESHOLD = 10_00;
  /// @dev Tier 2 slashing threshold ratio is 30%
  uint256 private constant TIER_2_THRESHOLD = 30_00;
  /// @dev Max percentage 100%. Values [0; 100_00] reflexes [0; 100%]
  uint256 private constant PERCENTAGE_FRACTION = 100_00;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.SlashBridgeIndicator.bridgeOperatorStatuses.slot") - 1
  bytes32 private constant BRIDGE_OPERATOR_STATUSES_SLOT =
    0x315ed8a0abb9fd55e40c49aa52c641ee78f97b4f2e33534e1bafd5daaa763881;

  function initialize(
    address validatorContract,
    address bridgeManagerContract,
    address bridgeTrackingContract
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
  }

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsAdded(
    address[] calldata bridgeOperators,
    bool[] memory addeds
  ) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint256 length = bridgeOperators.length;
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    mapping(address => BridgeOperatorStatus) storage _bridgeOperatorStatuses = _getBridgeOperatorStatuses();
    for (uint256 i; i < length; ) {
      if (addeds[i]) {
        _bridgeOperatorStatuses[bridgeOperators[i]].newlyAddedAtPeriod = uint192(currentPeriod);
      }
      unchecked {
        ++i;
      }
    }

    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsRemoved(
    address[] calldata,
    bool[] calldata
  ) external view onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorUpdated(
    address,
    address,
    bool
  ) external view onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    return IBridgeManagerCallback.onBridgeOperatorUpdated.selector;
  }

  /**
   * @inheritdoc IBridgeSlashing
   */
  function slashUnavailability(uint256 period) external onlyContract(ContractType.BRIDGE_TRACKING) {
    IBridgeManager bridgeManager = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER));

    uint256 totalBallotsForPeriod;
    uint256[] memory ballots;
    address[] memory allBridgeOperators;
    // get rid of stack too deep
    {
      allBridgeOperators = bridgeManager.getBridgeOperators();
      IBridgeTracking bridgeTracker = IBridgeTracking(msg.sender);
      totalBallotsForPeriod = bridgeTracker.totalBallots(period);
      ballots = bridgeTracker.getManyTotalBallots(period, allBridgeOperators);
    }

    uint256 length = allBridgeOperators.length;
    address[] memory bridgeOperatorsToRemoved = new address[](length);
    uint256 removeLength;
    {
      uint256[] memory penalizedDurations = _getPenalizedDurations();
      mapping(address => BridgeOperatorStatus) storage _bridgeOperatorStatuses = _getBridgeOperatorStatuses();

      BridgeOperatorStatus memory status;
      uint256 penalizedDuration;
      address bridgeOperator;
      Tier tier;

      for (uint256 i; i < length; ) {
        bridgeOperator = allBridgeOperators[i];
        status = _bridgeOperatorStatuses[bridgeOperator];

        if (status.newlyAddedAtPeriod < period) {
          tier = _getSlashTier(ballots[i], totalBallotsForPeriod);
          penalizedDuration = status.penalizedDuration + penalizedDurations[uint8(tier)];

          if (penalizedDuration >= REMOVE_DURATION_THRESHOLD) {
            bridgeOperatorsToRemoved[removeLength] = bridgeOperator;
            ++removeLength;
          }

          status.penalizedDuration = uint64(penalizedDuration);
          _bridgeOperatorStatuses[bridgeOperator] = status;

          emit Slashed(tier, bridgeOperator, period, block.timestamp + penalizedDuration);
        }

        unchecked {
          ++i;
        }
      }
    }

    // shorten bridgeOperatorsToRemoved array
    assembly {
      mstore(bridgeOperatorsToRemoved, removeLength)
    }

    bridgeManager.removeBridgeOperators(bridgeOperatorsToRemoved);
  }

  /**
   * @inheritdoc IBridgeSlashing
   */
  function penalizeDurationOf(address[] calldata bridgeOperators) external view returns (uint256[] memory durations) {
    uint256 length = bridgeOperators.length;
    durations = new uint256[](length);
    mapping(address => BridgeOperatorStatus) storage _bridgeOperatorStatuses = _getBridgeOperatorStatuses();
    for (uint256 i; i < length; ) {
      durations[i] = _bridgeOperatorStatuses[bridgeOperators[i]].penalizedDuration;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Gets the slash tier based on the given ballot and total ballots.
   * @param ballot The ballot count for a bridge operator.
   * @param totalBallots The total ballot count for the period.
   * @return tier The slash tier.
   */
  function _getSlashTier(uint256 ballot, uint256 totalBallots) internal pure virtual returns (Tier tier) {
    uint256 ratio = (ballot * PERCENTAGE_FRACTION) / totalBallots;
    tier = ratio > TIER_2_PENALIZE_DURATION ? Tier.Tier2 : ratio > TIER_1_PENALIZE_DURATION ? Tier.Tier1 : Tier.Tier0;
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeOperatorStatus.
   * @return bridgeOperatorStatuses_ the mapping from governor => BridgeOperatorInfo.
   */
  function _getBridgeOperatorStatuses()
    internal
    pure
    returns (mapping(address => BridgeOperatorStatus) storage bridgeOperatorStatuses_)
  {
    assembly {
      bridgeOperatorStatuses_.slot := BRIDGE_OPERATOR_STATUSES_SLOT
    }
  }

  function _getPenalizedDurations() internal pure virtual returns (uint256[] memory penalizedDurations) {
    penalizedDurations = new uint256[](3);
    // reserve index 0
    penalizedDurations[uint8(Tier.Tier1)] = TIER_1_PENALIZE_DURATION;
    penalizedDurations[uint8(Tier.Tier2)] = TIER_2_PENALIZE_DURATION;
  }
}
