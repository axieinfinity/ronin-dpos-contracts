// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract HasProxyAdmin {
  error ErrUnauthorized();

  // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  modifier onlyAdmin() {
    _requiresAdmin();
    _;
  }

  function _requiresAdmin() internal view {
    assembly {
      if iszero(eq(caller(), sload(_ADMIN_SLOT))) {
        /// @dev value is equal to bytes4(keccak256("ErrUnauthorized()"))
        mstore(0x00, 0xcc12cef6)
        revert(0x1c, 0x04)
      }
    }
  }

  /**
   * @dev Returns proxy admin.ƒ
   */
  function _getAdmin() internal view returns (address admin) {
    assembly {
      admin := sload(_ADMIN_SLOT)
    }
  }
}
