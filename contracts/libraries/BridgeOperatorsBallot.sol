// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/consumers/WeightedAddressConsumer.sol";

library BridgeOperatorsBallot {
  // keccak256("BridgeOperator(address addr,uint256 weight)");
  bytes32 public constant BRIDGE_OPERATOR_TYPEHASH = 0xe71132f1797176c8456299d5325989bbf16523f1e2e3aef4554d23f982955a2c;

  /**
   * @dev Returns hash of an operator struct.
   */
  function hash(WeightedAddressConsumer.WeightedAddress calldata _operator) internal pure returns (bytes32) {
    return keccak256(abi.encode(BRIDGE_OPERATOR_TYPEHASH, _operator.addr, _operator.weight));
  }

  // keccak256("BridgeOperatorsBallot(uint256 period,BridgeOperator[] operators)BridgeOperator(address addr,uint256 weight)");
  bytes32 public constant BRIDGE_OPERATORS_ACKNOWLEDGE_BALLOT_TYPEHASH =
    0x086d287088869477577720f66bf2a8412510e726fd1a893739cf6c2280aadcb5;

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(uint256 _period, WeightedAddressConsumer.WeightedAddress[] calldata _operators)
    internal
    pure
    returns (bytes32)
  {
    bytes32[] memory _hashArr = new bytes32[](_operators.length);
    for (uint256 _i; _i < _hashArr.length; _i++) {
      _hashArr[_i] = hash(_operators[_i]);
    }

    bytes32 _operatorsHash;
    assembly {
      _operatorsHash := keccak256(add(_hashArr, 32), mul(mload(_hashArr), 32))
    }

    return keccak256(abi.encode(BRIDGE_OPERATORS_ACKNOWLEDGE_BALLOT_TYPEHASH, _period, _operatorsHash));
  }
}
