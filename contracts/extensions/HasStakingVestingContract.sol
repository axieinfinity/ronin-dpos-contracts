// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../interfaces/collections/IHasStakingVestingContract.sol";
import "../interfaces/IStakingVesting.sol";

contract HasStakingVestingContract is IHasStakingVestingContract, HasProxyAdmin {
  IStakingVesting internal _stakingVestingContract;

  modifier onlyStakingVestingContract() {
    require(
      stakingVestingContract() == msg.sender,
      "HasStakingVestingContract: method caller must be staking vesting contract"
    );
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
    _setStakingVestingContract(_addr);
  }

  /**
   * @dev Sets the staking vesting contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `StakingVestingContractUpdated`.
   *
   */
  function _setStakingVestingContract(address _addr) internal {
    _stakingVestingContract = IStakingVesting(_addr);
    emit StakingVestingContractUpdated(_addr);
  }
}
