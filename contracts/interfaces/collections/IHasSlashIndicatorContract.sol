// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasSlashIndicatorContract is IHasContract {
  /// @dev Emitted when the slash indicator contract is updated.
  event SlashIndicatorContractUpdated(address);

  /**
   * @dev Returns the slash indicator contract.
   */
  function slashIndicatorContract() external view returns (address);

  /**
   * @dev Sets the slash indicator contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `SlashIndicatorContractUpdated`.
   *
   */
  function setSlashIndicatorContract(address) external;
}
