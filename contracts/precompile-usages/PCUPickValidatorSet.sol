// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./PrecompiledUsage.sol";

abstract contract PCUPickValidatorSet is PrecompiledUsage {
  /// @dev Gets the address of the precompile of picking validator set
  function precompilePickValidatorSetAddress() public view virtual returns (address) {
    return address(0x68);
  }

  /**
   * @dev Sorts and arranges to return a new validator set.
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _pcPickValidatorSet(
    address[] memory _candidates,
    uint256[] memory _weights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) internal view virtual returns (address[] memory _result, uint256 _newValidatorCount) {
    address _smc = precompilePickValidatorSetAddress();
    bytes memory _payload = abi.encodeWithSignature(
      "pickValidatorSet(address[],uint256[],uint256[],uint256,uint256)",
      _candidates,
      _weights,
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
    }

    if (!_success) revert ErrCallPrecompiled();

    _newValidatorCount = _result.length;
  }
}
