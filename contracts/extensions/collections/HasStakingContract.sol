// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasStakingContract.sol";
import "../../interfaces/staking/IStaking.sol";

contract HasStakingContract is IHasStakingContract, HasProxyAdmin {
  IStaking internal _stakingContract;

  modifier onlyStakingContract() {
    require(stakingContract() == msg.sender, "HasStakingManager: method caller must be staking contract");
    _;
  }

  /**
   * @inheritdoc IHasStakingContract
   */
  function stakingContract() public view override returns (address) {
    return address(_stakingContract);
  }

  /**
   * @inheritdoc IHasStakingContract
   */
  function setStakingContract(address _addr) external override onlyAdmin {
    _setStakingContract(_addr);
  }

  /**
   * @dev Sets the staking contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `StakingContractUpdated`.
   *
   */
  function _setStakingContract(address _addr) internal {
    _stakingContract = IStaking(_addr);
    emit StakingContractUpdated(_addr);
  }
}
