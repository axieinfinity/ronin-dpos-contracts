// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasStakingVestingContract.sol";
import "../../interfaces/IStakingVesting.sol";

contract HasStakingVestingContract is IHasStakingVestingContract, HasProxyAdmin {
  IStakingVesting internal _stakingVestingContract;

  modifier onlyStakingVestingContract() {
    if (stakingVestingContract() != msg.sender) revert ErrUnauthorized(msg.sig, Role.STAKING_VESTING_CONTRACT);
    _;
  }

  /**
   * @inheritdoc IHasStakingVestingContract
   */
  function stakingVestingContract() public view override returns (address) {
    return address(_stakingVestingContract);
  }

  /**
   * @inheritdoc IHasStakingVestingContract
   */
  function setStakingVestingContract(address _addr) external override onlyAdmin {
    if (_addr.code.length == 0) revert ErrZeroCodeContract(msg.sig);
    _setStakingVestingContract(_addr);
  }

  /**
   * @dev Sets the staking vesting contract.
   *
   * Emits the event `StakingVestingContractUpdated`.
   *
   */
  function _setStakingVestingContract(address _addr) internal {
    _stakingVestingContract = IStakingVesting(_addr);
    emit StakingVestingContractUpdated(_addr);
  }
}
