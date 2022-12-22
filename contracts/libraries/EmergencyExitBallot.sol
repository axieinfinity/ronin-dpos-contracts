// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library EmergencyExitBallot {
  // keccak256("EmergencyExitBallot(address consensusAddress,address recipientAfterUnlockedFund,uint256 requestedAt,uint256 expiredAt)");
  bytes32 public constant EMERGENCY_EXIT_BALLOT_TYPEHASH =
    0x697acba4deaf1a718d8c2d93e42860488cb7812696f28ca10eed17bac41e7027;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(
    address _consensusAddress,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          EMERGENCY_EXIT_BALLOT_TYPEHASH,
          _consensusAddress,
          _recipientAfterUnlockedFund,
          _requestedAt,
          _expiredAt
        )
      );
  }
}
