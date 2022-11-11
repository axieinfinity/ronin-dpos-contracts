// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../extensions/collections/HasBridgeTrackingContract.sol";
import "../../interfaces/validator/IBaseRoninValidatorSet.sol";
import "../../libraries/Math.sol";
import "../../libraries/EnumFlags.sol";
import "../../precompile-usages/PrecompileUsageSortValidators.sol";
import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";
import "./CandidateManager.sol";

abstract contract BaseRoninValidatorSet is IBaseRoninValidatorSet, HasRoninTrustedOrganizationContract {
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;

  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal _maxPrioritizedValidatorNumber;

  /**
   * @inheritdoc IBaseRoninValidatorSet
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  /**
   * @inheritdoc IBaseRoninValidatorSet
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return _maxPrioritizedValidatorNumber;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               FUNCTIONS FOR ADMIN                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IBaseRoninValidatorSet
   */
  function setMaxValidatorNumber(uint256 _max) external override onlyAdmin {
    _setMaxValidatorNumber(_max);
  }

  /**
   * @inheritdoc IBaseRoninValidatorSet
   */
  function setMaxPrioritizedValidatorNumber(uint256 _number) external override onlyAdmin {
    _setMaxPrioritizedValidatorNumber(_number);
  }

  /**
   * @dev See {IRoninValidatorSet-setMaxValidatorNumber}
   */
  function _setMaxValidatorNumber(uint256 _number) internal {
    _maxValidatorNumber = _number;
    emit MaxValidatorNumberUpdated(_number);
  }

  /**
   * @dev See {IRoninValidatorSet-setMaxPrioritizedValidatorNumber}
   */
  function _setMaxPrioritizedValidatorNumber(uint256 _number) internal {
    require(
      _number <= _maxValidatorNumber,
      "RoninValidatorSet: cannot set number of prioritized greater than number of max validators"
    );

    _maxPrioritizedValidatorNumber = _number;
    emit MaxPrioritizedValidatorNumberUpdated(_number);
  }

  /**
   * @dev Updates the number of blocks in epoch
   *
   * Emits the event `NumberOfBlocksInEpochUpdated`
   *
   */
  function _setNumberOfBlocksInEpoch(uint256 _number) internal {
    _numberOfBlocksInEpoch = _number;
    emit NumberOfBlocksInEpochUpdated(_number);
  }
}
