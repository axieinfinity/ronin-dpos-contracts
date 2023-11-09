// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library EmergencyExitBallot {
  // NOTE: The "address consensusAddress" is not changed in order to preserve the type hash. Since the EmergencyExitBallot
  // is not a library and is hashed by param feeds, not change the type hash still assure the contract to works correctly.

  // keccak256("EmergencyExitBallot(address consensusAddress,address recipientAfterUnlockedFund,uint256 requestedAt,uint256 expiredAt)");
  bytes32 private constant EMERGENCY_EXIT_BALLOT_TYPEHASH =
    0x697acba4deaf1a718d8c2d93e42860488cb7812696f28ca10eed17bac41e7027;

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
