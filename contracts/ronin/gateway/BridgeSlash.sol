// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IHasContracts, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { IBridgeManagerCallback } from "../../interfaces/bridge/IBridgeManagerCallback.sol";
import { IBridgeTracking } from "../../interfaces/bridge/IBridgeTracking.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { Math } from "../../libraries/Math.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";

/**
 * @title BridgeSlash
 * @dev A contract that implements slashing functionality for bridge operators based on their availability.
 */
contract BridgeSlash is IBridgeSlash, IBridgeManagerCallback, IdentityGuard, Initializable, HasContracts {
  /// @inheritdoc IBridgeSlash
  uint256 public constant TIER_1_PENALTY_DURATION = 1;
  /// @inheritdoc IBridgeSlash
  uint256 public constant TIER_2_PENALTY_DURATION = 5;
  /// @inheritdoc IBridgeSlash
  uint256 public constant REMOVING_DURATION_THRESHOLD = 30;

  /// @dev Tier 1 slashing threshold ratio is 10%
  uint256 private constant TIER_1_THRESHOLD = 10_00;
  /// @dev Tier 2 slashing threshold ratio is 30%
  uint256 private constant TIER_2_THRESHOLD = 30_00;
  /// @dev Max percentage 100%. Values [0; 100_00] reflexes [0; 100%]
  uint256 private constant PERCENTAGE_FRACTION = 100_00;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeSlash.bridgeSlashInfos.slot") - 1
  bytes32 private constant BRIDGE_SLASH_INFOS_SLOT = 0xd08d185790a07c7b9b721e2713c8580010a57f31c72c16f6e80b831d0ee45bfe;

  constructor() {
    _disableInitializers();
  }

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
   * @inheritdoc IHasContracts
   */
  function setContract(ContractType contractType, address addr) external override onlySelfCall {
    _requireHasCode(addr);
    _setContract(contractType, addr);
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
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    for (uint256 i; i < length; ) {
      if (addeds[i]) {
        _bridgeSlashInfos[bridgeOperators[i]].newlyAddedAtPeriod = uint192(currentPeriod);
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
   * @inheritdoc IBridgeSlash
   */
  function execSlashBridgeOperators(
    address[] memory allBridgeOperators,
    uint256[] memory ballots,
    uint256 totalBallotsForPeriod,
    uint256 period
  ) external onlyContract(ContractType.BRIDGE_TRACKING) {
    // Get penalty durations for each slash tier.
    uint256[] memory penaltyDurations = _getPenaltyDurations();
    // Get the storage mapping for bridge slash information.
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();

    // Calculate the next period.
    uint256 nextPeriod = period + 1;

    // Declare variables for iteration.
    BridgeSlashInfo memory status;
    uint256 slashUntilPeriod;
    address bridgeOperator;
    Tier tier;

    uint256 length = allBridgeOperators.length;
    for (uint256 i; i < length; ) {
      bridgeOperator = allBridgeOperators[i];
      status = _bridgeSlashInfos[bridgeOperator];

      // Check if the bridge operator was added before the current period.
      // Bridge operators added in current period will not be slashed.
      if (status.newlyAddedAtPeriod < period) {
        // Determine the slash tier for the bridge operator based on their ballots.
        tier = _getSlashTier(ballots[i], totalBallotsForPeriod);

        // Calculate the slash until period number.
        slashUntilPeriod = penaltyDurations[uint8(tier)] + Math.max(nextPeriod, status.slashUntilPeriod);

        // Check if the slash duration exceeds the threshold for removal
        if (slashUntilPeriod - nextPeriod >= REMOVING_DURATION_THRESHOLD) {
          slashUntilPeriod = type(uint64).max;
          tier = Tier.Kick;
        }

        // Emit the Slashed event if the tier is not Tier 0.
        // Update the slash until period number for the bridge operator if the tier is not Tier 0.
        if (tier != Tier.Tier0) {
          emit Slashed(tier, bridgeOperator, period, slashUntilPeriod);
          status.slashUntilPeriod = uint64(slashUntilPeriod);
          _bridgeSlashInfos[bridgeOperator] = status;
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeSlash
   */
  function penaltyDurationOf(address[] calldata bridgeOperators) external view returns (uint256[] memory durations) {
    uint256 length = bridgeOperators.length;
    durations = new uint256[](length);
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    for (uint256 i; i < length; ) {
      durations[i] = _bridgeSlashInfos[bridgeOperators[i]].slashUntilPeriod;
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
    tier = ratio > TIER_2_PENALTY_DURATION ? Tier.Tier2 : ratio > TIER_1_PENALTY_DURATION ? Tier.Tier1 : Tier.Tier0;
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeSlashInfo.
   * @return bridgeSlashInfos_ the mapping from bridge operator => BridgeSlashInfo.
   */
  function _getBridgeSlashInfos()
    internal
    pure
    returns (mapping(address => BridgeSlashInfo) storage bridgeSlashInfos_)
  {
    assembly {
      bridgeSlashInfos_.slot := BRIDGE_SLASH_INFOS_SLOT
    }
  }

  function _getPenaltyDurations() internal pure virtual returns (uint256[] memory penaltyDurations) {
    penaltyDurations = new uint256[](3);
    // reserve index 0
    penaltyDurations[uint8(Tier.Tier1)] = TIER_1_PENALTY_DURATION;
    penaltyDurations[uint8(Tier.Tier2)] = TIER_2_PENALTY_DURATION;
  }
}
