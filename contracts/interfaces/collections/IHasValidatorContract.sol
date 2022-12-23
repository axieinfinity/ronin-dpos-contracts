// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IHasValidatorContract {
  /// @dev Emitted when the validator contract is updated.
  event ValidatorContractUpdated(address);

  /// @dev Error of method caller must be validator contract.
  error ErrCallerMustBeValidatorContract();
  /// @dev Error of set to non-contract.
  error ErrZeroCodeValidatorContract();

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
