// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IHasBridgeTrackingContract {
  /// @dev Emitted when the bridge tracking contract is updated.
  event BridgeTrackingContractUpdated(address);

  /// @dev Error of method caller must be bridge tracking contract.
  error ErrCallerMustBeBridgeTrackingContract();
  /// @dev Error of set to non-contract.
  error ErrZeroCodeBridgeTrackingContract();

  /**
   * @dev Returns the bridge tracking contract.
   */
  function bridgeTrackingContract() external view returns (address);

  /**
   * @dev Sets the bridge tracking contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `BridgeTrackingContractUpdated`.
   *
   */
  function setBridgeTrackingContract(address) external;
}
