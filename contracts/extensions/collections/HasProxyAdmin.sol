// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/StorageSlot.sol";

import "../../libraries/Errors.sol";

abstract contract HasProxyAdmin {
  // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  modifier onlyAdmin() {
    _onlyAdmin();
    _;
  }

  /**
   * @dev Returns proxy admin.
   */
  function _getAdmin() internal view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  function _onlyAdmin() internal view {
    if (msg.sender != _getAdmin()) revert ErrUnauthorized(msg.sig);
  }
}
