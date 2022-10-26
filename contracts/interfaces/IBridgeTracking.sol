// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeTracking {
  enum VoteKind {
    Deposit,
    Withdrawal,
    MainchainWithdrawal
  }

  /**
   * @dev Returns the total number of votes including deposits and withdrawals at the specific period `_period`.
   */
  function totalVotes(uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the total number of votes including deposits and withdrawals of a bridge operator at the specific
   * period `_period`.
   */
  function totalVotesOf(uint256 _period, address _bridgeOperator) external view returns (uint256);

  /**
   * @dev Records vote for a receipt and a operator.
   *
   * Requirements:
   * - The method caller is the bridge contract.
   *
   */
  function recordVote(
    VoteKind _kind,
    uint256 _requestId,
    address _operator
  ) external;
}
