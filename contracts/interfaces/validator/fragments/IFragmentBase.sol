// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IFragmentBase {
  /// @dev Emitted when the validator is punished.
  event ValidatorPunished(
    address indexed consensusAddr,
    uint256 indexed period,
    uint256 jailedUntil,
    uint256 deductedStakingAmount,
    bool blockProducerRewardDeprecated,
    bool bridgeOperatorRewardDeprecated
  );
}
