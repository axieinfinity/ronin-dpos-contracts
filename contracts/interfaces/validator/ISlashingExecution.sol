// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashingExecution {
  /// @dev Emitted when the validator is punished.
  event ValidatorPunished(
    address indexed consensusAddr,
    uint256 indexed period,
    uint256 jailedUntil,
    uint256 deductedStakingAmount,
    bool blockProducerRewardDeprecated,
    bool bridgeOperatorRewardDeprecated
  );
  /// @dev Emitted when the validator get out of jail by bailout.
  event ValidatorUnjailed(address indexed validator, uint256 period);

  /// @dev Error of cannot bailout due to high tier slash.
  error ErrCannotBailout(address validator);

  /**
   * @dev Finalize the slash request from slash indicator contract.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorPunished`.
   *
   */
  function execSlash(address validatorAddr, uint256 newJailedUntil, uint256 slashAmount, bool cannotBailout) external;

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
