// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract UsageSortValidators {
  /// @dev Gets the address of the precompile of sorting validators
  function precompileSortValidatorAddress() public view virtual returns (address);

  /**
   * @dev Sorting candidates descending by their weights by calling precompile contract.
   *
   * Note: This function is marked as virtual for being wrapping in mock contract for testing purpose.
   */
  function _sortCandidates(address[] memory _candidates, uint256[] memory _weights)
    internal
    view
    virtual
    returns (address[] memory _result)
  {
    address _smc = precompileSortValidatorAddress();
    bool _success = true;

    bytes memory _payload = abi.encodeWithSignature("sortValidators(address[],uint256[])", _candidates, _weights);
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
    }

    require(_success, "UsageSortValidators: call to precompile fails");
  }
}
