// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library EmergencyExitBallot {
  // keccak256("EmergencyExitBallot(address consensusAddress,address recipientAfterUnlockedFund,uint256 requestedAt)");
  bytes32 public constant EMERGENCY_EXIT_BALLOT_TYPEHASH =
    0x10e263cc106e7f73f987b170d2d40c1f3a1c905ac487982dec61e8bbceaa2071;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(
    address _consensusAddress,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(EMERGENCY_EXIT_BALLOT_TYPEHASH, _consensusAddress, _recipientAfterUnlockedFund, _requestedAt)
      );
  }
}
