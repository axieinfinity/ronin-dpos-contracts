// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeSlashing } from "../../interfaces/IBridgeSlashing.sol";
import { IBridgeManager } from "../../interfaces/IBridgeManager.sol";
import { IBridgeManagerCallback } from "../../interfaces/IBridgeManagerCallback.sol";
import { IBridgeTracking } from "../../interfaces/IBridgeTracking.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { ContractType } from "../../utils/ContractType.sol";

contract SlashBridgeIndicator is IBridgeSlashing, IBridgeManagerCallback, Initializable, HasContracts {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev Tier 1 slashing threshold ratio is 10%
  uint256 private constant TIER_1_THRESHOLD = 10_00;
  /// @dev Tier 2 slashing threshold ratio is 30%
  uint256 private constant TIER_2_THRESHOLD = 30_00;
  /// @dev Max percentage 100%. Values [0; 100_00] reflexes [0; 100%]
  uint256 private constant PERCENTAGE_FRACTION = 100_00;
  uint256 private constant TIER_1_PENALIZE_DURATION = 1 days;
  uint256 private constant TIER_2_PENALIZE_DURATION = 5 days;
  uint256 private constant REMOVE_DURATION_THRESHOLD = 30 days;

  mapping(address => uint256) private _addedPeriod;
  mapping(address => uint256) private _penalizedDurationsOf;

  function initialize(
    address validatorContract,
    address bridgeManagerContract,
    address bridgeTrackingContract
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
  }

  function onBridgeOperatorsAdded(
    address[] calldata bridgeOperators,
    bool[] memory addeds
  ) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint256 length = bridgeOperators.length;
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    for (uint256 i; i < length; ) {
      if (addeds[i]) {
        _addedPeriod[bridgeOperators[i]] = currentPeriod;
      }
      unchecked {
        ++i;
      }
    }

    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  function onBridgeOperatorsRemoved(
    address[] calldata,
    bool[] calldata
  ) external view onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  function onBridgeOperatorUpdated(
    address,
    address,
    bool
  ) external view onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    return IBridgeManagerCallback.onBridgeOperatorUpdated.selector;
  }

  function slashUnavailability(uint256 period) external onlyContract(ContractType.BRIDGE_TRACKING) {
    IBridgeTracking bridgeTracker = IBridgeTracking(msg.sender);
    IBridgeManager bridgeManager = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER));

    uint256[] memory penalizedDurations = _getPenalizedDurations();
    address[] memory allBridgeOperators = bridgeManager.getBridgeOperators();
    uint256[] memory ballots = bridgeTracker.getManyTotalBallots(period, allBridgeOperators);
    uint256 length = allBridgeOperators.length;
    address[] memory bridgeOperatorsToRemoved = new address[](length);
    uint256 totalBallotsForPeriod = bridgeTracker.totalBallots(period);

    uint256 penalizedDuration;
    address bridgeOperator;
    uint256 removeLength;
    Tier tier;

    for (uint256 i; i < length; ) {
      bridgeOperator = allBridgeOperators[i];
      if (_addedPeriod[bridgeOperator] < period) {
        tier = _getSlashTier(ballots[i], totalBallotsForPeriod);
        penalizedDuration = _penalizedDurationsOf[bridgeOperator] + penalizedDurations[uint8(tier)];

        if (penalizedDuration >= REMOVE_DURATION_THRESHOLD) {
          bridgeOperatorsToRemoved[removeLength] = bridgeOperator;
          ++removeLength;
        }

        _penalizedDurationsOf[bridgeOperator] = penalizedDuration;

        emit Slashed(tier, bridgeOperator, period, block.timestamp + penalizedDuration);
      }

      unchecked {
        ++i;
      }
    }

    // shorten bridgeOperatorsToRemoved array
    assembly {
      mstore(bridgeOperatorsToRemoved, removeLength)
    }

    bridgeManager.removeBridgeOperators(bridgeOperatorsToRemoved);
  }

  function penalizeDurationOf(address[] calldata bridgeOperators) external view returns (uint256[] memory durations) {
    uint256 length = bridgeOperators.length;
    durations = new uint256[](length);
    for (uint256 i; i < length; ) {
      durations[i] = _penalizedDurationsOf[bridgeOperators[i]];
      unchecked {
        ++i;
      }
    }
  }

  function _getSlashTier(uint256 ballot, uint256 totalBallots) internal pure virtual returns (Tier tier) {
    uint256 ratio = (ballot * PERCENTAGE_FRACTION) / totalBallots;
    tier = ratio > TIER_2_PENALIZE_DURATION ? Tier.Tier2 : ratio > TIER_1_PENALIZE_DURATION ? Tier.Tier1 : Tier.Tier0;
  }

  function _getPenalizedDurations() internal pure virtual returns (uint256[] memory penalizedDurations) {
    penalizedDurations = new uint256[](3);
    // reserve index 0
    penalizedDurations[uint8(Tier.Tier1)] = TIER_1_PENALIZE_DURATION;
    penalizedDurations[uint8(Tier.Tier2)] = TIER_2_PENALIZE_DURATION;
  }
}
