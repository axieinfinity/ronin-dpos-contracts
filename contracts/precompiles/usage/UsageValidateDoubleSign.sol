// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract UsageValidateDoubleSign {
  /// @dev Gets the address of the precompile of validating double sign evidence
  function precompileValidateDoubleSignAddress() public view virtual returns (address);

  /**
   * @dev Validate the two submitted block header if they are produced by the same address
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _validateEvidence(bytes calldata _header1, bytes calldata _header2)
    internal
    view
    virtual
    returns (bool _validEvidence)
  {
    address _smc = precompileValidateDoubleSignAddress();

    bytes memory _payload = abi.encodeWithSignature("validatingDoubleSignProof(bytes,bytes)", _header1, _header2);
    uint _payloadLength = _payload.length;
    uint[1] memory _output;

    bytes memory _revertReason = "SlashIndicator: call to precompile fails";

    assembly {
      let _payloadStart := add(_payload, 0x20)
      if iszero(staticcall(gas(), _smc, _payloadStart, _payloadLength, _output, 0x20)) {
        revert(add(0x20, _revertReason), mload(_revertReason))
      }
    }

    return (_output[0] != 0);
  }
}
