// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasSlashIndicatorContract.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";

contract HasSlashIndicatorContract is IHasSlashIndicatorContract, HasProxyAdmin {
  ISlashIndicator internal _slashIndicatorContract;

  modifier onlySlashIndicatorContract() {
    _requiresSlashIndicatorContract();
    _;
  }

  function _requiresSlashIndicatorContract() internal view {
    assembly {
      if iszero(eq(caller(), sload(_slashIndicatorContract.slot))) {
        mstore(0x00, 0xa2e7092c)
        revert(0x1c, 0x04)
      }
    }
  }

  /**
   * @inheritdoc IHasSlashIndicatorContract
   */
  function slashIndicatorContract() public view override returns (address addr) {
    assembly {
      addr := sload(_slashIndicatorContract.slot)
    }
  }

  /**
   * @inheritdoc IHasSlashIndicatorContract
   */
  function setSlashIndicatorContract(address _addr) external override onlyAdmin {
    assembly {
      if iszero(extcodesize(_addr)) {
        /// @dev value is equal to bytes4(keccak256("ErrZeroCodeContract()"))
        mstore(0x00, 0x7bcd5091)
        revert(0x1c, 0x04)
      }
    }
    _setSlashIndicatorContract(_addr);
  }

  /**
   * @dev Sets the slash indicator contract.
   *
   * Emits the event `SlashIndicatorContractUpdated`.
   *
   */
  function _setSlashIndicatorContract(address _addr) internal {
    assembly {
      sstore(_slashIndicatorContract.slot, _addr)
      mstore(0x00, _addr)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("SlashIndicatorContractUpdated(address)")
        0xaa5b07dd43aa44c69b70a6a2b9c3fcfed12b6e5f6323596ba7ac91035ab80a4f
      )
    }
  }
}
