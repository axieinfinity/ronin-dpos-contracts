// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Mintable {
  function mint(address _to, uint256 _tokenId) external returns (bool);
}
