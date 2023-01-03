// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasValidatorContract is IHasContract {
  /// @dev Emitted when the validator contract is updated.
  event ValidatorContractUpdated(address);

  /// @dev Error of method caller must be validator contract.
  error ErrCallerMustBeValidatorContract();

  /**
   * @dev Returns the validator contract.
   */
  function validatorContract() external view returns (address);

  /**
   * @dev Sets the validator contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `ValidatorContractUpdated`.
   *
   */
  function setValidatorContract(address) external;
}
