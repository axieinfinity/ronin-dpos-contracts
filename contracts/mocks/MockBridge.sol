// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../interfaces/IBridge.sol";

contract MockBridge is IBridge {
  /// @dev Mapping from validator address => last block that the bridge operator is added
  mapping(address => uint256) public bridgeOperatorAddedBlock;
  /// @dev Bridge operators array
  address[] public bridgeOperators;

  function replaceBridgeOperators(address[] calldata _list) external {
    address _addr;
    for (uint256 _i = 0; _i < _list.length; _i++) {
      _addr = _list[_i];
      if (bridgeOperatorAddedBlock[_addr] == 0) {
        bridgeOperators.push(_addr);
      }
      bridgeOperatorAddedBlock[_addr] = block.number;
    }

    {
      uint256 _i;
      while (_i < bridgeOperators.length) {
        _addr = bridgeOperators[_i];
        if (bridgeOperatorAddedBlock[_addr] < block.number) {
          delete bridgeOperatorAddedBlock[_addr];
          bridgeOperators[_i] = bridgeOperators[bridgeOperators.length - 1];
          bridgeOperators.pop();
          continue;
        }
        _i++;
      }
    }
  }

  function getBridgeOperators() external view override returns (address[] memory) {
    return bridgeOperators;
  }
}
