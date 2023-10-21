// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./PrecompiledUsage.sol";

abstract contract PCUValidateFastFinality is PrecompiledUsage {
  /// @dev Gets the address of the precompile of validating double sign evidence
  function precompileValidateFastFinalityAddress() public view virtual returns (address) {
    return address(0x69);
  }

  /**
   * @dev Validates the proof of malicious voting on fast finality
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _pcValidateFastFinalityEvidence(
    bytes memory voterPublicKey,
    uint256 targetBlockNumber,
    bytes32[2] memory targetBlockHash,
    bytes[][2] memory listOfPublicKey,
    bytes[2] memory aggregatedSignature
  ) internal view virtual returns (bool validEvidence) {
    address smc = precompileValidateFastFinalityAddress();
    bool success = true;

    bytes memory payload = abi.encodeWithSignature(
      "validateFinalityVoteProof(bytes,uint256,bytes32[2],bytes[][2],bytes[2])",
      voterPublicKey,
      targetBlockNumber,
      targetBlockHash,
      listOfPublicKey,
      aggregatedSignature
    );
    uint payloadLength = payload.length;
    uint[1] memory output;

    assembly {
      let payloadStart := add(payload, 0x20)
      if iszero(staticcall(gas(), smc, payloadStart, payloadLength, output, 0x20)) {
        success := 0
      }

      if iszero(returndatasize()) {
        success := 0
      }
    }

    if (!success) revert ErrCallPrecompiled();
    return (output[0] != 0);
  }
}
