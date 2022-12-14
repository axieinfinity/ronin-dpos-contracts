// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IERC20Mintable {
  function mint(address _to, uint256 _value) external returns (bool _success);
}
