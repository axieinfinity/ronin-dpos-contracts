// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../ronin/gateway/RoninGatewayV3.sol";

contract MockRoninGatewayV3Extended is RoninGatewayV3 {
  /*
   * @dev Returns the vote weight for a deposit based on its corressponding hash.
   */
  function getDepositVoteWeight(
    uint256 _chainId,
    uint256 _depositId,
    bytes32 _hash
  ) external view returns (uint256 totalWeight) {
    totalWeight = _getVoteWeight(depositVote[_chainId][_depositId], _hash);
  }

  /**
   * @dev Returns the vote weight for a mainchain withdrew acknowledgement based on its corressponding hash.
   */
  function getMainchainWithdrewVoteWeight(
    uint256 _withdrawalId,
    bytes32 _hash
  ) external view returns (uint256 totalWeight) {
    totalWeight = _getVoteWeight(mainchainWithdrewVote[_withdrawalId], _hash);
  }

  /**
   * @dev Returns the vote weight for a withdraw stats based on its corressponding hash.
   */
  function getWithdrawalStatVoteWeight(
    uint256 _withdrawalId,
    bytes32 _hash
  ) external view returns (uint256 totalWeight) {
    totalWeight = _getVoteWeight(withdrawalStatVote[_withdrawalId], _hash);
  }
}
