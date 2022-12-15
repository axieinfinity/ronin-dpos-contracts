// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";

contract MockPrecompileUsagePickValidatorSet is PrecompileUsagePickValidatorSet {
  address internal _precompilePickValidatorSetAddress;

  constructor(address _precompile) {
    setPrecompilePickValidatorSetAddress(_precompile);
  }

  function setPrecompilePickValidatorSetAddress(address _addr) public {
    _precompilePickValidatorSetAddress = _addr;
  }

  function precompilePickValidatorSetAddress() public view override returns (address) {
    return _precompilePickValidatorSetAddress;
  }

  function callPrecompile(
    address[] memory _candidates,
    uint256[] memory _weights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) public view returns (address[] memory _result) {
    (_result, ) = _pcPickValidatorSet(
      _candidates,
      _weights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
  }
}
