// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract PrecompileUsagePickValidatorSet {
  /// @dev Gets the address of the precompile of picking validator set
  function precompilePickValidatorSet() public view virtual returns (address);

  /**
   * @dev Sorting and arranging to return a new validator set.
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _pickValidatorSet(
    address[] memory _candidates,
    uint256[] memory _balanceWeights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) internal view virtual returns (address[] memory _result, uint256 _newValidatorCount) {
    address _smc = precompilePickValidatorSet();
    bytes memory _payload = abi.encodeWithSignature(
      "pickValidatorSet(address[],uint256[],uint256[],uint256,uint256)",
      _candidates,
      _balanceWeights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    bool _success = true;

    uint256 _payloadLength = _payload.length;
    uint256 _resultLength = 0x20 * _candidates.length + 0x40;

    assembly {
      let _payloadStart := add(_payload, 0x20)

      if iszero(staticcall(gas(), _smc, _payloadStart, _payloadLength, _result, _resultLength)) {
        _success := 0
      }

      if iszero(returndatasize()) {
        _success := 0
      }

      _result := add(_result, 0x20)
      _newValidatorCount := _result
    }

    require(_success, "PrecompileUsageSortValidators: call to precompile fails");
  }
}
