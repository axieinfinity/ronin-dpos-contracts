// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompile-usages/PCUPickValidatorSet.sol";

contract MockPCUPickValidatorSet is PCUPickValidatorSet {
  address internal _precompileSortValidatorAddress;

  constructor(address _precompile) {
    setPrecompileSortValidatorAddress(_precompile);
  }

  function setPrecompileSortValidatorAddress(address _addr) public {
    _precompileSortValidatorAddress = _addr;
  }

  function precompilePickValidatorSetAddress() public view override returns (address) {
    return _precompileSortValidatorAddress;
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
