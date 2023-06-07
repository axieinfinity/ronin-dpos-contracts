// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libraries/CommonErrors.sol";

library BridgeOperatorsBallot {
  /**
   * @dev Error thrown when an invalid order of the bridge operator is detected.
   */
  error ErrInvalidOrderOfBridgeOperator();

  struct BridgeOperatorSet {
    uint256 period;
    uint256 epoch;
    address[] operators;
  }

  // keccak256("BridgeOperatorsBallot(uint256 period,uint256 epoch,address[] operators)");
  bytes32 public constant BRIDGE_OPERATORS_BALLOT_TYPEHASH =
    0xd679a49e9e099fa9ed83a5446aaec83e746b03ec6723d6f5efb29d37d7f0b78a;

  /**
   * @dev Verifies whether the ballot is valid or not.
   *
   * Requirements:
   * - The ballot is not for an empty operator set.
   * - The operator address list is in order.
   *
   */
  function verifyBallot(BridgeOperatorSet calldata _ballot) internal pure {
    if (_ballot.operators.length == 0) revert ErrEmptyArray();
    address _addr = _ballot.operators[0];
    for (uint _i = 1; _i < _ballot.operators.length; ) {
      if (_addr >= _ballot.operators[_i]) revert ErrInvalidOrderOfBridgeOperator();
      _addr = _ballot.operators[_i];
      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(BridgeOperatorSet memory self) internal pure returns (bytes32 digest) {
    bytes32 _operatorsHash;
    address[] memory _operators = self.operators;

    assembly {
      _operatorsHash := keccak256(add(_operators, 32), mul(mload(_operators), 32))
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, BRIDGE_OPERATORS_BALLOT_TYPEHASH)
      mstore(add(freeMemPtr, 0x20), mload(self)) // _ballot.period
      mstore(add(freeMemPtr, 0x40), mload(add(self, 0x20))) // _ballot.epoch
      mstore(add(freeMemPtr, 0x60), _operatorsHash)
      digest := keccak256(freeMemPtr, 0x80)
    }
  }
}
