// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/ICommonInfo.sol";
import "./JailingStorage.sol";
import "./TimingStorage.sol";
import "./ValidatorInfoStorage.sol";

abstract contract CommonStorage is ICommonInfo, TimingStorage, JailingStorage, ValidatorInfoStorage {
  /// @dev Mapping from consensus address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from consensus address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  /// @dev The total reward for bridge operators
  uint256 internal _totalBridgeReward;
  /// @dev Mapping from consensus address => pending reward for being bridge operator
  mapping(address => uint256) internal _bridgeOperatingReward;

  /// @dev The deprecated reward that has not been withdrawn by admin
  uint256 internal _totalDeprecatedReward;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[49] private ______gap;

  /**
   * @inheritdoc ITimingInfo
   */
  function epochOf(uint256 _block)
    public
    view
    virtual
    override(ITimingInfo, JailingStorage, TimingStorage)
    returns (uint256)
  {
    return TimingStorage.epochOf(_block);
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriod() public view virtual override(ITimingInfo, JailingStorage, TimingStorage) returns (uint256) {
    return TimingStorage.currentPeriod();
  }
}
