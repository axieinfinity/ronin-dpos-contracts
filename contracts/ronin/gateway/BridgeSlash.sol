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
   * @dev The modifier verifies if the `totalVotesForPeriod` is non-zero, indicating the presence of ballots for the period.
   * @param totalVotesForPeriod The total number of ballots for the period.
   */
  modifier onlyPeriodHasVotes(uint256 totalVotesForPeriod) {
    if (totalVotesForPeriod == 0) return;
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
    uint256 length = bridgeOperators.length;
    if (length != addeds.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) {
      return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
    }

    uint256 numAdded;
    address[] memory adddedBridgeOperators = new address[](length);
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();

    for (uint256 i; i < length; ) {
      unchecked {
        if (addeds[i]) {
          _bridgeSlashInfos[bridgeOperators[i]].newlyAddedAtPeriod = uint192(currentPeriod);
          adddedBridgeOperators[numAdded++] = bridgeOperators[i];
        }

        ++i;
      }
    }

    // resize adddedBridgeOperators array
    assembly ("memory-safe") {
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
  function onBridgeOperatorUpdated(
    address currentBridgeOperator,
    address newBridgeOperator
  ) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();
    BridgeSlashInfo memory currentSlashInfo = _bridgeSlashInfos[currentBridgeOperator];
    BridgeSlashInfo memory newSlashInfo = _bridgeSlashInfos[newBridgeOperator];

    newSlashInfo.slashUntilPeriod = uint64(Math.max(currentSlashInfo.slashUntilPeriod, newSlashInfo.slashUntilPeriod));
    newSlashInfo.newlyAddedAtPeriod = uint192(
      Math.max(currentSlashInfo.newlyAddedAtPeriod, newSlashInfo.newlyAddedAtPeriod)
    );

    _bridgeSlashInfos[newBridgeOperator] = newSlashInfo;

    delete _bridgeSlashInfos[currentBridgeOperator];

    return IBridgeManagerCallback.onBridgeOperatorUpdated.selector;
  }

  /**
   * @inheritdoc IBridgeSlash
   */
  function execSlashBridgeOperators(
    address[] memory allBridgeOperators,
    uint256[] memory ballots,
    uint256 totalVotesForPeriod,
    uint256 period
  ) external onlyContract(ContractType.BRIDGE_TRACKING) onlyPeriodHasVotes(totalVotesForPeriod) returns (bool slashed) {
    uint256 length = allBridgeOperators.length;
    if (length != ballots.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) slashed;

    // Get penalty durations for each slash tier.
    uint256[] memory penaltyDurations = _getPenaltyDurations();
    // Get the storage mapping for bridge slash information.
    mapping(address => BridgeSlashInfo) storage _bridgeSlashInfos = _getBridgeSlashInfos();

    // Declare variables for iteration.
    BridgeSlashInfo memory status;
    uint256 slashUntilPeriod;
    address bridgeOperator;
    Tier tier;

    for (uint256 i; i < length; ) {
      bridgeOperator = allBridgeOperators[i];
      status = _bridgeSlashInfos[bridgeOperator];

      // Check if the bridge operator was added before the current period.
      // Bridge operators added in current period will not be slashed.
      if (status.newlyAddedAtPeriod < period) {
        // Determine the slash tier for the bridge operator based on their ballots.
        tier = _getSlashTier(ballots[i], totalVotesForPeriod);

        slashUntilPeriod = _calcSlashUntilPeriod(tier, period, status.slashUntilPeriod, penaltyDurations);

        // Check if the slash duration exceeds the threshold for removal.
        if (_isSlashDurationMetRemovalThreshold(slashUntilPeriod, period)) {
          slashUntilPeriod = SLASH_PERMANENT_DURATION;
          emit RemovalRequested(period, bridgeOperator);
        }

        // Emit the Slashed event if the tier is not Tier 0 and bridge operator will not be removed.
        // Update the slash until period number for the bridge operator if the tier is not Tier 0.
        if (tier != Tier.Tier0) {
          slashed = true;

          if (slashUntilPeriod != SLASH_PERMANENT_DURATION) {
            emit Slashed(tier, bridgeOperator, period, slashUntilPeriod);
          }

          // Store updated slash until period
          _bridgeSlashInfos[bridgeOperator].slashUntilPeriod = uint64(slashUntilPeriod);
        }
      }

      unchecked {
        ++i;
      }
    }
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
   * @inheritdoc IBridgeSlash
   */
  function getPenaltyDurations() external pure returns (uint256[] memory penaltyDurations) {
    penaltyDurations = _getPenaltyDurations();
  }

  /**
   * @inheritdoc IBridgeSlash
   */
  function getSlashTier(uint256 ballot, uint256 totalVotes) external pure returns (Tier tier) {
    tier = _getSlashTier(ballot, totalVotes);
  }

  /**
   * @dev Checks if the slash duration exceeds the threshold for removal and handles it accordingly.
   * @param slashUntilPeriod The slash until period number.
   * @param period The current period.
   * @return met A boolean indicates that the threshold for removal is met.
   */
  function _isSlashDurationMetRemovalThreshold(
    uint256 slashUntilPeriod,
    uint256 period
  ) internal pure returns (bool met) {
    met = slashUntilPeriod - (period - 1) >= REMOVE_DURATION_THRESHOLD;
  }

  /**
   * @dev Calculates the slash until period based on the specified tier, current period, and slash until period.
   * @param tier The slash tier representing the severity of the slash.
   * @param period The current period in which the calculation is performed.
   * @param slashUntilPeriod The existing slash until period.
   * @param penaltyDurations An array of penalty durations for each slash tier.
   * @return newSlashUntilPeriod The newly calculated slash until period.
   */
  function _calcSlashUntilPeriod(
    Tier tier,
    uint256 period,
    uint256 slashUntilPeriod,
    uint256[] memory penaltyDurations
  ) internal pure returns (uint256 newSlashUntilPeriod) {
    // Calculate the slash until period number.
    newSlashUntilPeriod = penaltyDurations[uint8(tier)] + Math.max(period - 1, slashUntilPeriod);
  }

  function _getSlashTier(uint256 ballot, uint256 totalVotes) internal pure virtual returns (Tier tier) {
    uint256 ratio = ((totalVotes - ballot) * PERCENTAGE_FRACTION) / totalVotes;
    tier = ratio > TIER_2_THRESHOLD ? Tier.Tier2 : ratio > TIER_1_THRESHOLD ? Tier.Tier1 : Tier.Tier0;
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeSlashInfo.
   * @return bridgeSlashInfos the mapping from bridge operator => BridgeSlashInfo.
   */
  function _getBridgeSlashInfos() internal pure returns (mapping(address => BridgeSlashInfo) storage bridgeSlashInfos) {
    assembly ("memory-safe") {
      bridgeSlashInfos.slot := BRIDGE_SLASH_INFOS_SLOT
    }
  }

  function _getPenaltyDurations() internal pure virtual returns (uint256[] memory penaltyDurations) {
    // reserve index 0
    penaltyDurations = new uint256[](3);
    penaltyDurations[uint8(Tier.Tier1)] = TIER_1_PENALTY_DURATION;
    penaltyDurations[uint8(Tier.Tier2)] = TIER_2_PENALTY_DURATION;
  }
}
