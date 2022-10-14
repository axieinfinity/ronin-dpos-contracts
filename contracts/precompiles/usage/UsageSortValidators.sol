// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract UsageSortValidators {
  address public precompileSortValidatorAddress;

  constructor(address _precompile) {
    precompileSortValidatorAddress = _precompile;
  }

  address[] internal _validators = [
    0x0000000000000000000000000000000000000064,
    0x0000000000000000000000000000000000000065,
    0x0000000000000000000000000000000000000066,
    0x0000000000000000000000000000000000000067,
    0x0000000000000000000000000000000000000068,
    0x0000000000000000000000000000000000000069,
    0x000000000000000000000000000000000000006a,
    0x000000000000000000000000000000000000006b,
    0x000000000000000000000000000000000000006C,
    0x000000000000000000000000000000000000006D,
    0x000000000000000000000000000000000000006E,
    0x000000000000000000000000000000000000006F,
    0x0000000000000000000000000000000000000070,
    0x0000000000000000000000000000000000000071,
    0x0000000000000000000000000000000000000072,
    0x0000000000000000000000000000000000000073,
    0x0000000000000000000000000000000000000074,
    0x0000000000000000000000000000000000000075,
    0x0000000000000000000000000000000000000076,
    0x0000000000000000000000000000000000000077,
    0x0000000000000000000000000000000000000078
  ];
  uint256[] internal _weights = [
    1000,
    2000,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
    10000,
    11000,
    12000,
    13000,
    14000,
    15000,
    16000,
    17000,
    18000,
    19000,
    20000,
    21000
  ];

  function callPrecompile() public view returns (address[] memory _result) {
    bytes memory _payload = abi.encodeWithSignature("sortValidators(address[],uint256[])", _validators, _weights);

    uint256 _payloadLength = _payload.length;
    uint256 _resultLength = 0x20 * _validators.length + 0x40;
    address _smc = precompileSortValidatorAddress;

    assembly {
      let _payloadStart := add(_payload, 0x20)

      if iszero(staticcall(gas(), _smc, _payloadStart, _payloadLength, _result, _resultLength)) {
        revert(0, 0)
      }
      _result := add(_result, 0x20)
    }
  }

  function setPrecompileSortValidatorAddress(address _addr) external {
    precompileSortValidatorAddress = _addr;
  }

  function getValidators() public view returns (address[] memory validators_) {
    validators_ = new address[](_validators.length);
    for (uint _i = 0; _i < _validators.length; _i++) {
      validators_[_i] = _validators[_i];
    }
  }

  function getWeights() public view returns (uint256[] memory weights_) {
    weights_ = new uint256[](_weights.length);
    for (uint _i = 0; _i < _weights.length; _i++) {
      weights_[_i] = _weights[_i];
    }
  }
}
