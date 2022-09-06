// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ISlashIndicator.sol";

contract MockEmptyValidatorSet {
  ISlashIndicator private __slashingContract;

  function _setSlashingContract() internal view virtual returns (ISlashIndicator) {
    return __slashingContract;
  }

  function setSlashingContract(ISlashIndicator _addr) external {
    __slashingContract = _addr;
  }

  function slashFelony(address _addr) external {}

  function slashMisdemeanor(address _addr) external {}

  function resetCounters(address[] calldata _addr) external {
    __slashingContract.resetCounters(_addr);
  }
}
