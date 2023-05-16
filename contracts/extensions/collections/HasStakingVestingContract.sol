// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasStakingVestingContract.sol";
import "../../interfaces/IStakingVesting.sol";

contract HasStakingVestingContract is IHasStakingVestingContract, HasProxyAdmin {
  IStakingVesting internal _stakingVestingContract;

  modifier onlyStakingVestingContract() {
    if (stakingVestingContract() != msg.sender) revert ErrCallerMustBeStakingVestingContract();
    _;
  }

  /**
   * @inheritdoc IHasStakingVestingContract
   */
  function stakingVestingContract() public view override returns (address addr) {
    assembly {
      addr := sload(_stakingVestingContract.slot)
    }
  }

  /**
   * @inheritdoc IHasStakingVestingContract
   */
  function setStakingVestingContract(address _addr) external override onlyAdmin {
    assembly {
      if iszero(extcodesize(_addr)) {
        /// @dev value is equal to bytes4(keccak256("ErrZeroCodeContract()"))
        mstore(0x00, 0x7bcd5091)
        revert(0x1c, 0x04)
      }
    }
    _setStakingVestingContract(_addr);
  }

  /**
   * @dev Sets the staking vesting contract.
   *
   * Emits the event `StakingVestingContractUpdated`.
   *
   */
  function _setStakingVestingContract(address _addr) internal {
    assembly {
      sstore(_stakingVestingContract.slot, _addr)
      mstore(0x00, _addr)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("StakingVestingContractUpdated(address)")
        0xc328090a37d855191ab58469296f98f87a851ca57d5cdfd1e9ac3c83e9e7096d
      )
    }
  }
}
