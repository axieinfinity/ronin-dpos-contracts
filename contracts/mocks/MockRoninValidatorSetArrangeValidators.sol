// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../validator/RoninValidatorSet.sol";

contract MockRoninValidatorSetArrangeValidators is RoninValidatorSet {
  constructor() RoninValidatorSet() {}

  function arrangeValidatorCandidates(address[] memory _candidates, uint _newValidatorCount)
    external
    view
    returns (address[] memory)
  {
    return _arrangeValidatorCandidates(_candidates, _newValidatorCount);
  }
}
