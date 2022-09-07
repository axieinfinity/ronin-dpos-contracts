// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IRoninValidatorSet.sol";
import "../../interfaces/ISlashIndicator.sol";

contract MockSlashIndicator is ISlashIndicator {
  IRoninValidatorSet public validatorContract;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller is not the coinbase");
    _;
  }

  constructor(IRoninValidatorSet _validatorSetContract) {
    validatorContract = _validatorSetContract;
  }

  function slashFelony(address _validatorAddr) external {
    validatorContract.slashFelony(_validatorAddr);
  }

  function slashMisdemeanor(address _validatorAddr) external {
    validatorContract.slashMisdemeanor(_validatorAddr);
  }

  function resetCounters(address[] calldata) external {}

  function slash(address _valAddr) external override {}

  function slashDoubleSign(address _valAddr, bytes calldata _evidence) external override {}

  function getSlashIndicator(address _validator) external view override returns (uint256) {}

  function getSlashThresholds()
    external
    view
    override
    returns (uint256 misdemeanorThreshold, uint256 felonyThreshold)
  {}

  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) external override {}

  function governanceAdminContract() external view override returns (address) {}
}
