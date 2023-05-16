// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasStakingContract.sol";
import "../../interfaces/staking/IStaking.sol";

contract HasStakingContract is IHasStakingContract, HasProxyAdmin {
  IStaking internal _stakingContract;

  modifier onlyStakingContract() {
    _requiresStakingContract();
    _;
  }

  function _requiresStakingContract() internal view {
    assembly {
      if iszero(eq(caller(), sload(_stakingContract.slot))) {
        mstore(0x00, 0x8aaf4a07)
        revert(0x1c, 0x04)
      }
    }
  }

  /**
   * @inheritdoc IHasStakingContract
   */
  function stakingContract() public view override returns (address addr) {
    assembly {
      addr := sload(_stakingContract.slot)
    }
  }

  /**
   * @inheritdoc IHasStakingContract
   */
  function setStakingContract(address _addr) external override onlyAdmin {
    assembly {
      if iszero(extcodesize(_addr)) {
        /// @dev value is equal to bytes4(keccak256("ErrZeroCodeContract()"))
        mstore(0x00, 0x7bcd5091)
        revert(0x1c, 0x04)
      }
    }
    _setStakingContract(_addr);
  }

  /**
   * @dev Sets the staking contract.
   *
   * Emits the event `StakingContractUpdated`.
   *
   */
  function _setStakingContract(address _addr) internal {
    assembly {
      sstore(_stakingContract.slot, _addr)
      mstore(0x00, _addr)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("StakingContractUpdated(address)")
        0x6397f5b135542bb3f477cb346cfab5abdec1251d08dc8f8d4efb4ffe122ea0bf
      )
    }
  }
}
