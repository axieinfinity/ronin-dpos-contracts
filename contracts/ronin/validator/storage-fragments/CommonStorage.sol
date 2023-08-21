// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/ICommonInfo.sol";
import "./JailingStorage.sol";
import "./TimingStorage.sol";
import "./ValidatorInfoStorageV2.sol";

abstract contract CommonStorage is ICommonInfo, TimingStorage, JailingStorage, ValidatorInfoStorageV2 {
  /// @dev Mapping from consensus address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from consensus address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  /// @dev The total reward for fast finality
  uint256 internal _totalFastFinalityReward;
  /// @dev Mapping from consensus address => pending reward for fast finality
  mapping(address => uint256) internal _fastFinalityReward;

  /// @dev The deprecated reward that has not been withdrawn by admin
  uint256 internal _totalDeprecatedReward;

  /// @dev The amount of RON to lock from a consensus address.
  uint256 internal _emergencyExitLockedAmount;
  /// @dev The duration that an emergency request is expired and the fund will be recycled.
  uint256 internal _emergencyExpiryDuration;
  /// @dev The address list of consensus addresses that being locked fund.
  address[] internal _lockedConsensusList;
  /// @dev Mapping from consensus => request exist info
  mapping(address => EmergencyExitInfo) internal _exitInfo;
  /// @dev Mapping from consensus => flag indicating whether the locked fund is released
  mapping(address => bool) internal _lockedFundReleased;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[44] private ______gap;

  /**
   * @inheritdoc ICommonInfo
   */
  function getEmergencyExitInfo(
    address _consensusAddr
  ) external view override returns (EmergencyExitInfo memory _info) {
    _info = _exitInfo[_consensusAddr];
    if (_info.recyclingAt == 0) revert NonExistentRecyclingInfo();
  }

  /**
   * @inheritdoc ICommonInfo
   */
  function totalDeprecatedReward() external view override returns (uint256) {
    return _totalDeprecatedReward;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function epochOf(
    uint256 _block
  ) public view virtual override(ITimingInfo, JailingStorage, TimingStorage) returns (uint256) {
    return TimingStorage.epochOf(_block);
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriod() public view virtual override(ITimingInfo, JailingStorage, TimingStorage) returns (uint256) {
    return TimingStorage.currentPeriod();
  }
}
