// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1967Upgrade } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import { ErrorHandler } from "../../libraries/ErrorHandler.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ErrOnlySelfCall } from "../CommonErrors.sol";

/**
 * @title ConditionalVersionControl
 * @dev A contract that allows conditional version control of contract implementations.
 */
abstract contract ConditionalVersionControl is ERC1967Upgrade {
  using ErrorHandler for bool;
  using AddressArrayUtils for address[];

  error ErrInvalidArguments(address proxyStorage, address currentVersion, address newVersion);
  /// @dev Error of set to non-contract.
  error ErrZeroCodeContract(address addr);
  /// @dev Error when contract which delegate to this contract is not compatible with ERC1967
  error ErrDelegateFromUnknownOrigin(address addr);

  address internal immutable _proxyStorage;
  address internal immutable _newVersion;
  address internal immutable _currentVersion;

  modifier onlySelfCall() {
    _requireSelfCall();
    _;
  }

  /**
   * @dev Modifier that only allows delegate calls from admin proxy storage.
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
   * @dev Constructs the ConditionalVersionControl contract.
   * @param proxyStorage The address of the proxy that is allowed to delegate to this contract.
   * @param currentVersion The address of the current contract implementation.
   * @param newVersion The address of the new contract implementation.
   */
  constructor(
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) onlyContract(proxyStorage) onlyContract(currentVersion) onlyContract(newVersion) {
    address[] memory addrs = new address[](3);
    addrs[0] = proxyStorage;
    addrs[1] = currentVersion;
    addrs[2] = newVersion;
    if (addrs.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);

    _proxyStorage = proxyStorage;
    _newVersion = newVersion;
    _currentVersion = currentVersion;
  }

  /**
   * @dev Fallback function that forwards the call to the current or new contract implementation based on a condition.
   */
  fallback() external payable virtual onlyDelegateFromProxyStorage {
    bytes memory returnData = _dispatchCall(_chooseVersion());
    _triggerMigration();
    assembly {
      return(add(returnData, 0x20), mload(returnData))
    }
  }

  receive() external payable {
    revert();
  }

  function upgrade() external onlyDelegateFromProxyStorage onlySelfCall {
    _upgradeTo(_newVersion);
  }

  function _chooseVersion() internal view virtual returns (address) {
    return _isConditionMet() ? _newVersion : _currentVersion;
  }

  function _dispatchCall(address version) internal virtual returns (bytes memory returnData) {
    (bool success, bytes memory returnOrRevertData) = version.delegatecall(msg.data);
    success.handleRevert(msg.sig, returnOrRevertData);
    assembly {
      returnData := returnOrRevertData
    }
  }

  function _triggerMigration() internal virtual {
    if (_isConditionMet()) {
      try this.upgrade{ gas: _gasStipenedNoGrief() }() {} catch {}
    }
  }

  /**
   * @dev Internal function to check if the condition for switching implementations is met.
   * @return A boolean indicating if the condition is met.
   */
  function _isConditionMet() internal view virtual returns (bool);

  /**
   * @dev Internal function to check if a contract address has code.
   * @param addr The address of the contract to check.
   * @dev Throws an error if the contract address has no code.
   */
  function _requireHasCode(address addr) internal view {
    if (addr.code.length == 0) revert ErrZeroCodeContract(addr);
  }

  /**
   * @dev Internal function to check if the caller is delegating from proxy storage.
   * @dev Throws an error if the current implementation of the proxy storage is not this contract.
   */
  function _requireDelegateFromProxyStorage() private view {
    if (address(this) != _proxyStorage) revert ErrDelegateFromUnknownOrigin(address(this));
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
    if (msg.sender != _proxyStorage) revert ErrOnlySelfCall(msg.sig);
  }

  function _gasStipenedNoGrief() internal pure virtual returns (uint256) {
    /// @dev Suggested gas stipend for contract to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    /// Multiply by a small constant (e.g. 2), if needed.
    return 50_000;
  }
}
