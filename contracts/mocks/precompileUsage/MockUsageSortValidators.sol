// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompiles/usage/UsageSortValidators.sol";

contract MockUsageSortValidators is UsageSortValidators {
  address internal _precompileSortValidatorAddress;

  constructor(address _precompile) {
    setPrecompileSortValidatorAddress(_precompile);
  }

  function setPrecompileSortValidatorAddress(address _addr) public {
    _precompileSortValidatorAddress = _addr;
  }

  function precompileSortValidatorAddress() public view override returns (address) {
    return _precompileSortValidatorAddress;
  }

  function callPrecompile(address[] calldata _validators, uint256[] calldata _weights)
    public
    view
    returns (address[] memory _result)
  {
    return _sortCandidates(_validators, _weights);
  }
}
