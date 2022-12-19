// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library BridgeOperatorsBallot {
  // keccak256("BridgeOperatorsBallot(uint256 period,uint256 epoch,address[] operators)");
  bytes32 public constant BRIDGE_OPERATORS_BALLOT_TYPEHASH =
    0xd679a49e9e099fa9ed83a5446aaec83e746b03ec6723d6f5efb29d37d7f0b78a;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(
    uint256 _period,
    uint256 _epoch,
    address[] memory _operators
  ) internal pure returns (bytes32) {
    bytes32 _operatorsHash;
    assembly {
      _operatorsHash := keccak256(add(_operators, 32), mul(mload(_operators), 32))
    }

    return keccak256(abi.encode(BRIDGE_OPERATORS_BALLOT_TYPEHASH, _period, _epoch, _operatorsHash));
  }
}
