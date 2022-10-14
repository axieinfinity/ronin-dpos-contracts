// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract UsageValidateDoubleSign {
  address public precompileValidateDoubleSignAddress;

  constructor(address _precompile) {
    precompileValidateDoubleSignAddress = _precompile;
  }

  function callPrecompile(bytes calldata _header1, bytes calldata _header2) public view returns (bool) {
    address _smc = precompileValidateDoubleSignAddress;

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
