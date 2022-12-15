// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";

abstract contract IsolatedGovernance is VoteStatusConsumer {
  struct IsolatedVote {
    VoteStatus status;
    bytes32 finalHash;
    /// @dev Mapping from voter => receipt hash
    mapping(address => bytes32) voteHashOf;
    /// @dev Mapping from receipt hash => vote weight
    mapping(bytes32 => uint256) weight;
    /// @dev The timestamp that voting is expired (no expiration=0)
    uint256 expiredAt;
    /// @dev The timestamp that voting is created
    uint256 createdAt;
  }

  /**
   * @dev Casts vote for the receipt with the receipt hash `_hash`.
   *
   * Requirements:
   * - The vote is not finalized.
   * - The voter has not voted for the round.
   *
   */
  function _castVote(
    IsolatedVote storage _proposal,
    address _voter,
    uint256 _voterWeight,
    uint256 _minimumVoteWeight,
    bytes32 _hash
  ) internal virtual returns (VoteStatus _status) {
    if (_proposal.expiredAt > 0 && _proposal.expiredAt <= block.timestamp) {
      _proposal.status = VoteStatus.Expired;
      return _proposal.status;
    }

    if (_voted(_proposal, _voter)) {
      revert(
        string(abi.encodePacked("IsolatedGovernance: ", Strings.toHexString(uint160(_voter), 20), " already voted"))
      );
    }

    // Record for voter
    _proposal.voteHashOf[_voter] = _hash;
    // Increase vote weight
    uint256 _weight = _proposal.weight[_hash] += _voterWeight;

    if (_weight >= _minimumVoteWeight && _proposal.status == VoteStatus.Pending) {
      _proposal.status = VoteStatus.Approved;
      _proposal.finalHash = _hash;
    }

    _status = _proposal.status;
  }

  /**
   * @dev Returns whether the voter casted for the proposal.
   */
  function _voted(IsolatedVote storage _proposal, address _voter) internal view virtual returns (bool) {
    return _proposal.voteHashOf[_voter] != bytes32(0);
  }
}
