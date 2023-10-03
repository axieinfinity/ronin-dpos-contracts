/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HasContracts } from "../collections/HasContracts.sol";
import { IConditionalImplementControl } from "../../interfaces/version-control/IConditionalImplementControl.sol";
import { ErrorHandler } from "../../libraries/ErrorHandler.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ErrOnlySelfCall, IdentityGuard } from "../../utils/IdentityGuard.sol";

/**
 * @title ConditionalImplementControl
 * @dev A contract that allows conditional version control of contract implementations.
 */
abstract contract ConditionalImplementControl is IConditionalImplementControl, IdentityGuard, HasContracts {
  using ErrorHandler for bool;
  using AddressArrayUtils for address[];

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  /// @dev value is equal to keccak256("@ronin.extensions.version-control.ConditionalImplementControl.calldatas.slot") - 1
  bytes32 internal constant CALLDATAS_SLOT = 0x330d87be17f5b23d41285647e0e9b0e7124a778feb3f952590ed6a023ae02633;

  /**
   * @dev address of the proxy that delegates to this contract.
   * @notice immutable variables are directly stored in contract code.
   * ensuring no storage writes are required.
   * The values of immutable variables remain fixed and cannot be modified,
   * regardless of any interactions, including delegations.
   */
  address public immutable PROXY_STORAGE;
  /**
   * @dev The address of the new implementation.
   */
  address public immutable NEW_IMPL;
  /**
   * @dev The address of the previous implementation.
   */
  address public immutable PREV_IMPL;

  /**
   * @dev Modifier that executes the function when conditions are met.
   */
  modifier whenConditionsAreMet() virtual {
    _;
    if (_isConditionMet()) {
      try this.selfUpgrade{ gas: _gasStipenedNoGrief() }() {} catch {}
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
   * @dev Constructs the ConditionalImplementControl contract.
   * @param proxyStorage The address of the proxy that is allowed to delegate to this contract.
   * @param prevImpl The address of the current contract implementation.
   * @param newImpl The address of the new contract implementation.
   */
  constructor(address proxyStorage, address prevImpl, address newImpl) {
    _requireHasCode(newImpl);
    _requireHasCode(prevImpl);
    _requireHasCode(proxyStorage);

    address[] memory addrs = new address[](3);
    addrs[0] = proxyStorage;
    addrs[1] = prevImpl;
    addrs[2] = newImpl;
    if (addrs.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);

    PROXY_STORAGE = proxyStorage;
    NEW_IMPL = newImpl;
    PREV_IMPL = prevImpl;
  }

  /**
   * @dev Fallback function that forwards the call to the current or new contract implementation based on a condition.
   */
  fallback() external payable virtual onlyDelegateFromProxyStorage {
    _fallback();
  }

  /**
   * @dev Receive function that forwards the call to the current or new contract implementation based on a condition.
   */
  receive() external payable virtual onlyDelegateFromProxyStorage {
    _fallback();
  }

  /**
   * @dev See {IConditionalImplementControl-selfUpgrade}.
   */
  function selfUpgrade() external virtual onlyDelegateFromProxyStorage onlySelfCall {
    _upgradeTo(NEW_IMPL);
  }

  /**
   * @dev See {IConditionalImplementControl-setCallDatas}.
   */
  function setCallDatas(bytes[] calldata args) external onlyAdmin onlyDelegateFromProxyStorage {
    bytes[] storage callDatas = _callDatas();
    uint256 length = args.length;
    for (uint256 i; i < length; ) {
      callDatas.push(args[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to access the array of calldatas.
   * @return callDatas the storage array of calldatas.
   */
  function _callDatas() internal pure returns (bytes[] storage callDatas) {
    assembly ("memory-safe") {
      callDatas.slot := CALLDATAS_SLOT
    }
  }

  function _upgradeTo(address newImplementation) internal {
    assembly ("memory-safe") {
      sstore(_IMPLEMENTATION_SLOT, newImplementation)
    }
    emit Upgraded(newImplementation);

    bytes[] storage callDatas = _callDatas();
    uint256 length = callDatas.length;
    bool success;
    bytes memory returnOrRevertData;
    for (uint256 i; i < length; ) {
      (success, returnOrRevertData) = newImplementation.delegatecall(callDatas[i]);
      success.handleRevert(bytes4(callDatas[i]), returnOrRevertData);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to get the current version of the contract implementation.
   * @return The address of the current version.
   */
  function _getConditionedImplementation() internal view virtual returns (address) {
    return _isConditionMet() ? NEW_IMPL : PREV_IMPL;
  }

  /**
   * @dev Internal function to check if the condition for switching implementation is met.
   * @return the boolean indicating if condition is met.
   */
  function _isConditionMet() internal view virtual returns (bool) {}

  /**
   * @dev Logic for fallback function.
   */
  function _fallback() internal virtual {
    bytes memory returnData = _dispatchCall(_getConditionedImplementation());
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
  function _requireSelfCall() internal view virtual override {
    if (msg.sender != PROXY_STORAGE) revert ErrOnlySelfCall(msg.sig);
  }

  /**
   * @dev Suggested gas stipend for contract to call {selfUpgrade} function.
   */
  function _gasStipenedNoGrief() internal pure virtual returns (uint256) {
    // Gas stipend for contract to perform a few read and write operations on storage, but
    // low enough to prevent comsuming gas exhaustively when function call are reverted.
    // Multiply by a small constant (e.g. 2), if needed.
    return 50_000;
  }
}
