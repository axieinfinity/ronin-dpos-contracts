// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompile-usages/PrecompileUsageValidateDoubleSign.sol";

contract MockPrecompileUsageValidateDoubleSign is PrecompileUsageValidateDoubleSign {
  address internal _precompileValidateDoubleSignAddress;

  constructor(address _precompile) {
    setPrecompileValidateDoubleSignAddress(_precompile);
  }

  function setPrecompileValidateDoubleSignAddress(address _addr) public {
    _precompileValidateDoubleSignAddress = _addr;
  }

  function precompileValidateDoubleSignAddress() public view override returns (address) {
    return _precompileValidateDoubleSignAddress;
  }

  function callPrecompile(bytes calldata _header1, bytes calldata _header2) public view returns (bool) {
    return _validateEvidence(_header1, _header2);
  }
}
