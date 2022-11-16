// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/ICommonInfo.sol";
import "./JailingStorage.sol";
import "./TimingStorage.sol";
import "./ValidatorInfoStorage.sol";

abstract contract CommonStorage is TimingStorage, JailingStorage, ValidatorInfoStorage, ICommonInfo {
  /// @dev Mapping from consensus address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from consensus address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  /// @dev The total reward for bridge operators
  uint256 internal _totalBridgeReward;
  /// @dev Mapping from consensus address => pending reward for being bridge operator
  mapping(address => uint256) internal _bridgeOperatingReward;
}
