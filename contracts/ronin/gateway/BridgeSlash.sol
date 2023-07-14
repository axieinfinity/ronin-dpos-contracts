// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IHasContracts, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { IERC165, IBridgeManagerCallback } from "../../interfaces/bridge/IBridgeManagerCallback.sol";
import { IBridgeTracking } from "../../interfaces/bridge/IBridgeTracking.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { Math } from "../../libraries/Math.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";
import { ErrLengthMismatch } from "../../utils/CommonErrors.sol";

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
  uint256 public constant REMOVE_DURATION_THRESHOLD = 30;

  /// @dev Tier 1 slashing threshold ratio is 10%
  uint256 private constant TIER_1_THRESHOLD = 10_00;
  /// @dev Tier 2 slashing threshold ratio is 30%
  uint256 private constant TIER_2_THRESHOLD = 30_00;
  /// @dev Max percentage 100%. Values [0; 100_00] reflexes [0; 100%]
  uint256 private constant PERCENTAGE_FRACTION = 100_00;
  /// @dev This value is set to the maximum value of uint64 to indicate a permanent slash duration.
  uint256 private constant SLASH_PERMANENT_DURATION = type(uint64).max;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeSlash.bridgeSlashInfos.slot") - 1
  bytes32 private constant BRIDGE_SLASH_INFOS_SLOT = 0xd08d185790a07c7b9b721e2713c8580010a57f31c72c16f6e80b831d0ee45bfe;

  /**
   * @dev The modifier verifies if the `totalBallotsForPeriod` is non-zero, indicating the presence of ballots for the period.
   * @param totalBallotsForPeriod The total number of ballots for the period.
   */
  modifier onlyPeriodHasBallots(uint256 totalBallotsForPeriod) {
    if (totalBallotsForPeriod == 0) return;
    _;
  }

  constructor() payable {
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
    if (bridgeOperators.length != addeds.length) revert ErrLengthMismatch(msg.sig);
    uint256 length = bridgeOperators.length;
    uint256 numAdded;
    address[] memory adddedBridgeOperators = new address[](length);
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    for (uint256 i; i < length; ) {
      unchecked {
        if (addeds[i]) {
          _bridgeSlashInfos[bridgeOperators[i]].newlyAddedAtPeriod = uint192(currentPeriod);
          adddedBridgeOperators[numAdded] = bridgeOperators[i];
          ++numAdded;
        }
        ++i;
      }
    }

    // resize adddedBridgeOperators array
    assembly {
      mstore(adddedBridgeOperators, numAdded)
    }

    if (numAdded != 0) {
      emit NewBridgeOperatorsAdded(currentPeriod, adddedBridgeOperators);
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
  ) external onlyPeriodHasBallots(totalBallotsForPeriod) onlyContract(ContractType.BRIDGE_TRACKING) {
    if (allBridgeOperators.length != ballots.length) revert ErrLengthMismatch(msg.sig);
    // Get penalty durations for each slash tier.
    uint256[] memory penaltyDurations = _getPenaltyDurations();
    // Get the storage mapping for bridge slash information.
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();

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
        slashUntilPeriod = penaltyDurations[uint8(tier)] + Math.max(period - 1, status.slashUntilPeriod);

        // Check if the slash duration exceeds the threshold for removal.
        if (slashUntilPeriod - (period - 1) >= REMOVE_DURATION_THRESHOLD) {
          slashUntilPeriod = SLASH_PERMANENT_DURATION;
          emit RemovalRequested(period, bridgeOperator);
        }

        // Emit the Slashed event if the tier is not Tier 0 and bridge operator will not be removed.
        // Update the slash until period number for the bridge operator if the tier is not Tier 0.
        if (tier != Tier.Tier0) {
          if (slashUntilPeriod != SLASH_PERMANENT_DURATION) {
            emit Slashed(tier, bridgeOperator, period, slashUntilPeriod);
          }
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
   * @inheritdoc IERC165
   */
  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return interfaceId == type(IBridgeManagerCallback).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /**
   * @inheritdoc IBridgeSlash
   */
  function getSlashUntilPeriodOf(
    address[] calldata bridgeOperators
  ) external view returns (uint256[] memory untilPeriods) {
    uint256 length = bridgeOperators.length;
    untilPeriods = new uint256[](length);
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    for (uint256 i; i < length; ) {
      untilPeriods[i] = _bridgeSlashInfos[bridgeOperators[i]].slashUntilPeriod;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeSlash
   */
  function getAddedPeriodOf(address[] calldata bridgeOperators) external view returns (uint256[] memory addedPeriods) {
    uint256 length = bridgeOperators.length;
    addedPeriods = new uint256[](length);
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    for (uint256 i; i < length; ) {
      addedPeriods[i] = _bridgeSlashInfos[bridgeOperators[i]].newlyAddedAtPeriod;
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
    tier = ratio > TIER_2_THRESHOLD ? Tier.Tier2 : ratio > TIER_1_THRESHOLD ? Tier.Tier1 : Tier.Tier0;
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeSlashInfo.
   * @return bridgeSlashInfos the mapping from bridge operator => BridgeSlashInfo.
   */
  function _getBridgeSlashInfos() internal pure returns (mapping(address => BridgeSlashInfo) storage bridgeSlashInfos) {
    assembly {
      bridgeSlashInfos.slot := BRIDGE_SLASH_INFOS_SLOT
    }
  }

  /**
   * @dev Internal function to retrieve the penalty durations for different slash tiers.
   * @return penaltyDurations The array of penalty durations for each slash tier.
   */
  function _getPenaltyDurations() internal pure virtual returns (uint256[] memory penaltyDurations) {
    penaltyDurations = new uint256[](3);
    // reserve index 0
    penaltyDurations[uint8(Tier.Tier1)] = TIER_1_PENALTY_DURATION;
    penaltyDurations[uint8(Tier.Tier2)] = TIER_2_PENALTY_DURATION;
  }
}
