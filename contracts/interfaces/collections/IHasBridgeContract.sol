// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IHasBridgeContract {
  /// @dev Emitted when the bridge contract is updated.
  event BridgeContractUpdated(address);

  /// @dev Error of method caller must be bridge contract.
  error ErrCallerMustBeBridgeContract();
  /// @dev Error of set to non-contract.
  error ErrZeroCodeBridgeContract();

  /**
   * @dev Returns the bridge contract.
   */
  function bridgeContract() external view returns (address);

  /**
   * @dev Sets the bridge contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `BridgeContractUpdated`.
   *
   */
  function setBridgeContract(address) external;
}
