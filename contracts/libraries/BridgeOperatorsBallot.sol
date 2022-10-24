// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/consumers/WeightedAddressConsumer.sol";

library BridgeOperatorsBallot {
  // keccak256("BridgeOperatorsBallot(uint256 period,address[] operators)");
  bytes32 public constant BRIDGE_OPERATORS_BALLOT_TYPEHASH =
    0xeea5e3908ac28cbdbbce8853e49444c558a0a03597e98ef19e6ff86162ed9ae3;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(uint256 _period, address[] memory _operators) internal pure returns (bytes32) {
    bytes32 _operatorsHash;
    assembly {
      _operatorsHash := keccak256(add(_operators, 32), mul(mload(_operators), 32))
    }

    return keccak256(abi.encode(BRIDGE_OPERATORS_BALLOT_TYPEHASH, _period, _operatorsHash));
  }
}
