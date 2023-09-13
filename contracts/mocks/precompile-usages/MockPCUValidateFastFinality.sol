// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../precompile-usages/PCUValidateFastFinality.sol";

contract MockPCUValidateFastFinality is PCUValidateFastFinality {
  address internal _precompileValidateFastFinalityAddress;

  constructor(address _precompile) {
    setPrecompileValidateFastFinalityAddress(_precompile);
  }

  function setPrecompileValidateFastFinalityAddress(address _addr) public {
    _precompileValidateFastFinalityAddress = _addr;
  }

  function precompileValidateFastFinalityAddress() public view override returns (address) {
    return _precompileValidateFastFinalityAddress;
  }

  function callPrecompile(
    bytes memory voterPublicKey,
    uint256 targetBlockNumber,
    bytes32[2] memory targetBlockHash,
    bytes[][2] memory listOfPublicKey,
    bytes[2] memory aggregatedSignature
  ) public view returns (bool) {
    return
      _pcValidateFastFinalityEvidence(
        voterPublicKey,
        targetBlockNumber,
        targetBlockHash,
        listOfPublicKey,
        aggregatedSignature
      );
  }
}
