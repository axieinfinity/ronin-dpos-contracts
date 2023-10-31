// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConditionalImplementControl {
  /// @dev Error when contract which delegate to this contract is not compatible with ERC1967
  error ErrDelegateFromUnknownOrigin(address addr);

  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);

  /**
   * @dev Executes the selfUpgrade function, upgrading to the new contract implementation.
   */
  function selfUpgrade() external;

  /**
   * @dev Set additional calldata to call when upgrading via `selfUpgrade`.
   */
  function setCallDatas(bytes[] calldata args) external;
}
