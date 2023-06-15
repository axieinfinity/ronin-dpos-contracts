// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrInvalidChainId, ErrLengthMismatch } from "../utils/CommonErrors.sol";

library Proposal {
  /**
   * @dev Error thrown when there is insufficient gas to execute a function.
   */
  error ErrInsufficientGas(bytes32 proposalHash);

  /**
   * @dev Error thrown when an invalid expiry timestamp is provided.
   */
  error ErrInvalidExpiryTimestamp();

  struct ProposalDetail {
    // Nonce to make sure proposals are executed in order
    uint256 nonce;
    // Value 0: all chain should run this proposal
    // Other values: only specifc chain has to execute
    uint256 chainId;
    uint256 expiryTimestamp;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    uint256[] gasAmounts;
  }

  // keccak256("ProposalDetail(uint256 nonce,uint256 chainId,uint256 expiryTimestamp,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 public constant TYPE_HASH = 0xd051578048e6ff0bbc9fca3b65a42088dbde10f36ca841de566711087ad9b08a;

  /**
   * @dev Validates the proposal.
   */
  function validate(ProposalDetail memory _proposal, uint256 _maxExpiryDuration) internal view {
    if (
      !(_proposal.targets.length > 0 &&
        _proposal.targets.length == _proposal.values.length &&
        _proposal.targets.length == _proposal.calldatas.length &&
        _proposal.targets.length == _proposal.gasAmounts.length)
    ) {
      revert ErrLengthMismatch(msg.sig);
    }

    if (_proposal.expiryTimestamp > block.timestamp + _maxExpiryDuration) {
      revert ErrInvalidExpiryTimestamp();
    }
  }

  /**
   * @dev Returns struct hash of the proposal.
   */
  function hash(ProposalDetail memory _proposal) internal pure returns (bytes32 digest_) {
    uint256[] memory _values = _proposal.values;
    address[] memory _targets = _proposal.targets;
    bytes32[] memory _calldataHashList = new bytes32[](_proposal.calldatas.length);
    uint256[] memory _gasAmounts = _proposal.gasAmounts;

    for (uint256 _i; _i < _calldataHashList.length; ) {
      _calldataHashList[_i] = keccak256(_proposal.calldatas[_i]);

      unchecked {
        ++_i;
      }
    }

    // return
    //   keccak256(
    //     abi.encode(
    //       TYPE_HASH,
    //       _proposal.nonce,
    //       _proposal.chainId,
    //       _targetsHash,
    //       _valuesHash,
    //       _calldatasHash,
    //       _gasAmountsHash
    //     )
    //   );
    // /
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, TYPE_HASH)
      mstore(add(ptr, 0x20), mload(_proposal)) // _proposal.nonce
      mstore(add(ptr, 0x40), mload(add(_proposal, 0x20))) // _proposal.chainId
      mstore(add(ptr, 0x60), mload(add(_proposal, 0x40))) // expiry timestamp

      let arrayHashed
      arrayHashed := keccak256(add(_targets, 32), mul(mload(_targets), 32)) // targetsHash
      mstore(add(ptr, 0x80), arrayHashed)
      arrayHashed := keccak256(add(_values, 32), mul(mload(_values), 32)) // _valuesHash
      mstore(add(ptr, 0xa0), arrayHashed)
      arrayHashed := keccak256(add(_calldataHashList, 32), mul(mload(_calldataHashList), 32)) // _calldatasHash
      mstore(add(ptr, 0xc0), arrayHashed)
      arrayHashed := keccak256(add(_gasAmounts, 32), mul(mload(_gasAmounts), 32)) // _gasAmountsHash
      mstore(add(ptr, 0xe0), arrayHashed)
      digest_ := keccak256(ptr, 0x100)
    }
  }

  /**
   * @dev Returns whether the proposal is executable for the current chain.
   *
   * @notice Does not check whether the call result is successful or not. Please use `execute` instead.
   *
   */
  function executable(ProposalDetail memory _proposal) internal view returns (bool _result) {
    return _proposal.chainId == 0 || _proposal.chainId == block.chainid;
  }

  /**
   * @dev Executes the proposal.
   */
  function execute(
    ProposalDetail memory _proposal
  ) internal returns (bool[] memory _successCalls, bytes[] memory _returnDatas) {
    if (!executable(_proposal)) revert ErrInvalidChainId(msg.sig, _proposal.chainId, block.chainid);

    _successCalls = new bool[](_proposal.targets.length);
    _returnDatas = new bytes[](_proposal.targets.length);
    for (uint256 _i = 0; _i < _proposal.targets.length; ) {
      if (gasleft() <= _proposal.gasAmounts[_i]) revert ErrInsufficientGas(hash(_proposal));

      (_successCalls[_i], _returnDatas[_i]) = _proposal.targets[_i].call{
        value: _proposal.values[_i],
        gas: _proposal.gasAmounts[_i]
      }(_proposal.calldatas[_i]);

      unchecked {
        ++_i;
      }
    }
  }
}
