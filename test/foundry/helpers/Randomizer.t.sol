// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Base_Test } from "../Base.t.sol";

abstract contract Randomizer is Base_Test {
  function _randomize(uint256 seed, uint256 min, uint256 max) internal pure returns (uint256 r) {
    r = _bound(uint256(keccak256(abi.encode(seed))), min, max);
  }

  function _createRandomAddresses(uint256 seed, uint256 amount) internal returns (address[] memory addrs) {
    addrs = new address[](amount);

    for (uint256 i; i < amount; ) {
      seed = uint256(keccak256(abi.encode(seed)));
      addrs[i] = vm.addr(seed);
      vm.etch(addrs[i], abi.encode());
      vm.deal(addrs[i], 1 ether);

      unchecked {
        ++i;
      }
    }
  }

  function _createRandomNumbers(
    uint256 seed,
    uint256 amount,
    uint256 min,
    uint256 max
  ) internal pure returns (uint256[] memory nums) {
    uint256 r;
    nums = new uint256[](amount);

    for (uint256 i; i < amount; ) {
      r = _randomize(seed, min, max);
      nums[i] = r;
      seed = r;

      unchecked {
        ++i;
      }
    }
  }
}
