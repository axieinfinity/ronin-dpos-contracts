// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IFragmentBase.sol";

interface IValidatorSetFragmentSlashing is IFragmentBase {
  /// @dev Emitted when the validator get out of jail by bailout.
  event ValidatorUnjailed(address indexed validator, uint256 period);

  /**
   * @dev Finalize the slash request from slash indicator contract.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorPunished`.
   *
   */
  function execSlash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external;

  /**
   * @dev Finalize the bailout request from slash indicator contract.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorUnjailed`.
   *
   */
  function execBailOut(address _validatorAddr, uint256 _period) external;
}
