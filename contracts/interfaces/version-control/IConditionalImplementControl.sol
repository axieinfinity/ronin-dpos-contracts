// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConditionalImplementControl {
  /// @dev Error of set to non-contract.
  error ErrZeroCodeContract(address addr);
  /// @dev Error when contract which delegate to this contract is not compatible with ERC1967
  error ErrDelegateFromUnknownOrigin(address addr);

  function selfMigrate() external;
}
