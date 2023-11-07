// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library EmergencyExitBallot {
  // keccak256("EmergencyExitBallot(address validatorId,address recipientAfterUnlockedFund,uint256 requestedAt,uint256 expiredAt)");
  bytes32 private constant EMERGENCY_EXIT_BALLOT_TYPEHASH =
    0x64e34629e995f7ed2919b1f05a7ad1f274a24512f6d0d8b5b057427f7adf6518;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(
    address validatorId,
    address recipientAfterUnlockedFund,
    uint256 requestedAt,
    uint256 expiredAt
  ) internal pure returns (bytes32 digest) {
    /*
     * return
     *   keccak256(
     *     abi.encode(
     *       EMERGENCY_EXIT_BALLOT_TYPEHASH,
     *       validatorId,
     *       recipientAfterUnlockedFund,
     *       requestedAt,
     *       expiredAt
     *     )
     *   );
     */
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, EMERGENCY_EXIT_BALLOT_TYPEHASH)
      mstore(add(ptr, 0x20), validatorId)
      mstore(add(ptr, 0x40), recipientAfterUnlockedFund)
      mstore(add(ptr, 0x60), requestedAt)
      mstore(add(ptr, 0x80), expiredAt)
      digest := keccak256(ptr, 0xa0)
    }
  }
}
