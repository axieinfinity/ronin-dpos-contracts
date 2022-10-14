// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../validator/RoninValidatorSet.sol";
import "../libraries/Sorting.sol";

contract MockRoninValidatorSetSorting is RoninValidatorSet {
  constructor() {}

  function _sortCandidates(address[] memory _candidates, uint256[] memory _weights)
    internal
    pure
    override
    returns (address[] memory _result)
  {
    return Sorting.sort(_candidates, _weights);
  }
}
