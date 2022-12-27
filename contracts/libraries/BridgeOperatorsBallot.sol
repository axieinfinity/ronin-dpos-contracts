// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library BridgeOperatorsBallot {
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
   * - The epoch and period are not older than the current ones.
   * - The bridge operator set is changed compared with the latest one.
   * - The operator address list is in order.
   *
   */
  function verifyBallot(BridgeOperatorSet calldata _ballot, BridgeOperatorSet storage _latest) internal view {
    require(_ballot.operators.length > 0, "BridgeOperatorsBallot: invalid array length");

    bytes32 _ballotOperatorsHash;
    bytes32 _latestOperatorsHash;
    address[] memory _ballotOperators = _ballot.operators;
    address[] memory _latestOperators = _latest.operators;

    assembly {
      _ballotOperatorsHash := keccak256(add(_ballotOperators, 32), mul(mload(_ballotOperators), 32))
      _latestOperatorsHash := keccak256(add(_latestOperators, 32), mul(mload(_latestOperators), 32))
    }

    require(
      _ballotOperatorsHash != _latestOperatorsHash,
      "BOsGovernanceProposal: bridge operator set is already voted"
    );

    address _addr = _ballotOperators[0];
    for (uint _i = 1; _i < _ballotOperators.length; _i++) {
      require(_addr < _ballotOperators[_i], "BOsGovernanceProposal: invalid order of bridge operators");
      _addr = _ballotOperators[_i];
    }
  }

  /**
   * @dev Returns hash of the ballot.
   */
  function hash(BridgeOperatorSet calldata _ballot) internal pure returns (bytes32) {
    bytes32 _operatorsHash;
    address[] memory _operators = _ballot.operators;

    assembly {
      _operatorsHash := keccak256(add(_operators, 32), mul(mload(_operators), 32))
    }

    return keccak256(abi.encode(BRIDGE_OPERATORS_BALLOT_TYPEHASH, _ballot.period, _ballot.epoch, _operatorsHash));
  }
}
