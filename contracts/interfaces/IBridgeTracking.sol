// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeTracking {
  enum VoteKind {
    Deposit,
    Withdrawal,
    MainchainWithdrawal
  }

  /**
   * @dev Returns the total number of votes at the specific period `_period`.
   */
  function totalVotes(uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the total number of ballots at the specific period `_period`.
   */
  function totalBallots(uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the total number of ballots of bridge operators at the specific period `_period`.
   */
  function getManyTotalBallots(uint256 _period, address[] calldata _bridgeOperators)
    external
    view
    returns (uint256[] memory);

  /**
   * @dev Returns the total number of ballots of a bridge operator at the specific period `_period`.
   */
  function totalBallotsOf(uint256 _period, address _bridgeOperator) external view returns (uint256);

  /**
   * @dev Handles the request once it is approved.
   *
   * Requirements:
   * - The method caller is the bridge contract.
   *
   */
  function handleVoteApproved(VoteKind _kind, uint256 _requestId) external;

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
