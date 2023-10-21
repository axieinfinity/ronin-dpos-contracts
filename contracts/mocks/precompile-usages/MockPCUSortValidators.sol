// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompile-usages/PCUSortValidators.sol";

contract MockPCUSortValidators is PCUSortValidators {
  address internal _precompileSortValidatorAddress;

  constructor(address _precompile) {
    setPrecompileSortValidatorAddress(_precompile);
  }

  function setPrecompileSortValidatorAddress(address _addr) public {
    _precompileSortValidatorAddress = _addr;
  }

  function precompileSortValidatorsAddress() public view override returns (address) {
    return _precompileSortValidatorAddress;
  }

  function callPrecompile(
    address[] calldata _validators,
    uint256[] calldata _weights
  ) public view returns (address[] memory _result) {
    return _pcSortCandidates(_validators, _weights);
  }
}
