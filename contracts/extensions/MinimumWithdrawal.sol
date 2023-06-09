// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./collections/HasProxyAdmin.sol";
import "../libraries/Transfer.sol";

abstract contract MinimumWithdrawal is HasProxyAdmin {
  /// @dev Throwed when the ERC20 withdrawal quantity is less than the minimum threshold.
  error ErrQueryForTooSmallQuantity();

  /// @dev Emitted when the minimum thresholds are updated
  event MinimumThresholdsUpdated(address[] tokens, uint256[] threshold);

  /// @dev Mapping from token address => minimum thresholds
  mapping(address => uint256) public minimumThreshold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @dev Sets the minimum thresholds to withdraw.
   *
   * Requirements:
   * - The method caller is admin.
   * - The arrays have the same length and its length larger than 0.
   *
   * Emits the `MinimumThresholdsUpdated` event.
   *
   */
  function setMinimumThresholds(address[] calldata _tokens, uint256[] calldata _thresholds) external virtual onlyAdmin {
    if (_tokens.length == 0) revert ErrEmptyArray();
    _setMinimumThresholds(_tokens, _thresholds);
  }

  /**
   * @dev Sets minimum thresholds.
   *
   * Requirements:
   * - The array lengths are equal.
   *
   * Emits the `MinimumThresholdsUpdated` event.
   *
   */
  function _setMinimumThresholds(address[] calldata _tokens, uint256[] calldata _thresholds) internal virtual {
    if (_tokens.length != _thresholds.length) revert ErrLengthMismatch(msg.sig);

    for (uint256 _i; _i < _tokens.length; ) {
      minimumThreshold[_tokens[_i]] = _thresholds[_i];

      unchecked {
        ++_i;
      }
    }
    emit MinimumThresholdsUpdated(_tokens, _thresholds);
  }

  /**
   * @dev Checks whether the request is larger than or equal to the minimum threshold.
   */
  function _checkWithdrawal(Transfer.Request calldata _request) internal view {
    if (_request.info.erc == Token.Standard.ERC20 && _request.info.quantity < minimumThreshold[_request.tokenAddr]) {
      revert ErrQueryForTooSmallQuantity();
    }
  }
}
