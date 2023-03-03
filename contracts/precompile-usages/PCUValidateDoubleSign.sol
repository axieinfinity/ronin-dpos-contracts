// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./PrecompiledUsage.sol";

abstract contract PCUValidateDoubleSign is PrecompiledUsage {
  /// @dev Gets the address of the precompile of validating double sign evidence
  function precompileValidateDoubleSignAddress() public view virtual returns (address) {
    return address(0x67);
  }

  /**
   * @dev Validates the two submitted block header if they are produced by the same address
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _pcValidateEvidence(
    address _consensusAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) internal view virtual returns (bool _validEvidence) {
    address _smc = precompileValidateDoubleSignAddress();
    bool _success = true;

    bytes memory _payload = abi.encodeWithSignature(
      "validatingDoubleSignProof(address,bytes,bytes)",
      _consensusAddr,
      _header1,
      _header2
    );
    uint _payloadLength = _payload.length;
    uint[1] memory _output;

    assembly {
      let _payloadStart := add(_payload, 0x20)
      if iszero(staticcall(gas(), _smc, _payloadStart, _payloadLength, _output, 0x20)) {
        _success := 0
      }

      if iszero(returndatasize()) {
        _success := 0
      }
    }

    if (!_success) revert ErrCallPrecompiled();
    return (_output[0] != 0);
  }
}
