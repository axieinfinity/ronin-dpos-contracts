// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeTracking {
  struct Request {
    VoteKind kind;
    uint256 id;
  }

  enum VoteKind {
    Deposit,
    Withdrawal,
    MainchainWithdrawal
  }

  event ExternalCallFailed(address indexed to, bytes4 indexed msgSig, bytes reason);

  /**
   * @dev Returns the block that allow incomming mutable call.
   */
  function startedAtBlock() external view returns (uint256);

  /**
   * @dev Returns the total number of votes at the specific period `_period`.
   */
  function totalVote(uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the total number of ballots at the specific period `_period`.
   */
  function totalBallot(uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the total number of ballots of bridge operators at the specific period `_period`.
   */
  function getManyTotalBallots(
    uint256 _period,
    address[] calldata _bridgeOperators
  ) external view returns (uint256[] memory);

  /**
   * @dev Returns the total number of ballots of a bridge operator at the specific period `_period`.
   */
  function totalBallotOf(uint256 _period, address _bridgeOperator) external view returns (uint256);

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
  function recordVote(VoteKind _kind, uint256 _requestId, address _operator) external;
}
