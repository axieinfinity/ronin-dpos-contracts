// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1967Upgrade } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import { IConditionalImplementControl } from "../../interfaces/version-control/IConditionalImplementControl.sol";
import { ErrorHandler } from "../../libraries/ErrorHandler.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ErrOnlySelfCall } from "../../utils/CommonErrors.sol";

/**
 * @title ConditionalImplementControl
 * @dev A contract that allows conditional version control of contract implementations.
 */
abstract contract ConditionalImplementControl is IConditionalImplementControl, ERC1967Upgrade {
  using ErrorHandler for bool;
  using AddressArrayUtils for address[];

  address public immutable PROXY_STORAGE;
  address public immutable NEW_VERSION;
  address public immutable CURRENT_VERSION;

  /**
   * @dev Modifier that only allows self calls.
   */
  modifier onlySelfCall() {
    _requireSelfCall();
    _;
  }

  /**
   * @dev Modifier that executes the function when conditions are met.
   */
  modifier whenConditionsAreMet() virtual {
    _;
    if (_isConditionMet()) {
      try this.selfMigrate{ gas: _gasStipenedNoGrief() }() {} catch {}
    }
  }

  /**
   * @dev Modifier that only allows delegate calls from the admin proxy storage.
   */
  modifier onlyDelegateFromProxyStorage() virtual {
    _requireDelegateFromProxyStorage();
    _;
  }

  /**
   * @dev Modifier that only allows contracts with code.
   * @param addr The address of the contract to check.
   */
  modifier onlyContract(address addr) {
    _requireHasCode(addr);
    _;
  }

  /**
   * @dev Constructs the ConditionalImplementControl contract.
   * @param proxyStorage_ The address of the proxy that is allowed to delegate to this contract.
   * @param currentVersion_ The address of the current contract implementation.
   * @param newVersion_ The address of the new contract implementation.
   */
  constructor(
    address proxyStorage_,
    address currentVersion_,
    address newVersion_
  ) onlyContract(proxyStorage_) onlyContract(currentVersion_) onlyContract(newVersion_) {
    address[] memory addrs = new address[](3);
    addrs[0] = proxyStorage_;
    addrs[1] = currentVersion_;
    addrs[2] = newVersion_;
    if (addrs.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);

    PROXY_STORAGE = proxyStorage_;
    NEW_VERSION = newVersion_;
    CURRENT_VERSION = currentVersion_;
  }

  /**
   * @dev Fallback function that forwards the call to the current or new contract implementation based on a condition.
   */
  fallback() external payable virtual onlyDelegateFromProxyStorage {
    _fallback();
  }

  receive() external payable virtual onlyDelegateFromProxyStorage {
    _fallback();
  }

  /**
   * @dev Executes the selfMigrate function, upgrading to the new contract implementation.
   */
  function selfMigrate() external onlyDelegateFromProxyStorage onlySelfCall {
    _upgradeTo(NEW_VERSION);
  }

  /**
   * @dev Internal function to get the current version of the contract implementation.
   * @return The address of the current version.
   */
  function _getVersion() internal view virtual returns (address);

  function _isConditionMet() internal view virtual returns (bool) {}

  function _fallback() internal virtual {
    bytes memory returnData = _dispatchCall(_getVersion());
    assembly {
      return(add(returnData, 0x20), mload(returnData))
    }
  }

  /**
   * @dev Internal function to dispatch the call to the specified version.
   * @param impl The address of the version to call.
   * @return returnData The return data of the call.
   */
  function _dispatchCall(address impl) internal virtual whenConditionsAreMet returns (bytes memory returnData) {
    (bool success, bytes memory returnOrRevertData) = impl.delegatecall(msg.data);
    success.handleRevert(msg.sig, returnOrRevertData);
    assembly {
      returnData := returnOrRevertData
    }
  }

  /**
   * @dev Internal function to check if a contract address has code.
   * Throws an error if the contract address has no code.
   * @param addr The address of the contract to check.
   */
  function _requireHasCode(address addr) internal view {
    if (addr.code.length == 0) revert ErrZeroCodeContract(addr);
  }

  /**
   * @dev Internal function to check if the caller is delegating from proxy storage.
   * Throws an error if the current implementation of the proxy storage is not this contract.
   */
  function _requireDelegateFromProxyStorage() private view {
    if (address(this) != PROXY_STORAGE) revert ErrDelegateFromUnknownOrigin(address(this));
  }

  /**
   * @dev Internal method to check method caller.
   *
   * Requirements:
   *
   * - The method caller must be this contract.
   *
   */
  function _requireSelfCall() internal view virtual {
    if (msg.sender != PROXY_STORAGE) revert ErrOnlySelfCall(msg.sig);
  }

  /**
   * @dev Suggested gas stipend for contract to call {selfMigrate} function.
   */
  function _gasStipenedNoGrief() internal pure virtual returns (uint256) {
    // Gas stipend for contract to perform a few read and write operations on storage, but
    // low enough to prevent comsuming gas exhaustively when function call are reverted.
    // Multiply by a small constant (e.g. 2), if needed.
    return 50_000;
  }
}
