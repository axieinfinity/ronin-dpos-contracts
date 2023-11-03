// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IBridgeManagerCallbackRegister } from "../../interfaces/bridge/IBridgeManagerCallbackRegister.sol";
import { IBridgeManagerCallback } from "../../interfaces/bridge/IBridgeManagerCallback.sol";
import { TransparentUpgradeableProxyV2, IdentityGuard } from "../../utils/IdentityGuard.sol";

/**
 * @title BridgeManagerCallbackRegister
 * @dev A contract that manages callback registrations and execution for a bridge.
 */
abstract contract BridgeManagerCallbackRegister is IdentityGuard, IBridgeManagerCallbackRegister {
  using EnumerableSet for EnumerableSet.AddressSet;

  /**
   * @dev Storage slot for the address set of callback registers.
   * @dev Value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.callbackRegisters.slot") - 1.
   */
  bytes32 private constant CALLBACK_REGISTERS_SLOT = 0x5da136eb38f8d8e354915fc8a767c0dc81d49de5fb65d5477122a82ddd976240;

  constructor(address[] memory callbackRegisters) payable {
    _registerCallbacks(callbackRegisters);
  }

  /**
   * @inheritdoc IBridgeManagerCallbackRegister
   */
  function registerCallbacks(address[] calldata registers) external onlySelfCall returns (bool[] memory registereds) {
    registereds = _registerCallbacks(registers);
  }

  /**
   * @inheritdoc IBridgeManagerCallbackRegister
   */
  function unregisterCallbacks(
    address[] calldata registers
  ) external onlySelfCall returns (bool[] memory unregistereds) {
    unregistereds = _unregisterCallbacks(registers);
  }

  /**
   * @inheritdoc IBridgeManagerCallbackRegister
   */
  function getCallbackRegisters() external view returns (address[] memory registers) {
    registers = _getCallbackRegisters().values();
  }

  /**
   * @dev Internal function to register multiple callbacks with the bridge.
   * @param registers The array of callback addresses to register.
   * @return registereds An array indicating the success status of each registration.
   */
  function _registerCallbacks(
    address[] memory registers
  ) internal nonDuplicate(registers) returns (bool[] memory registereds) {
    uint256 length = registers.length;
    registereds = new bool[](length);
    if (length == 0) return registereds;

    EnumerableSet.AddressSet storage _callbackRegisters = _getCallbackRegisters();
    address register;
    bytes4 callbackInterface = type(IBridgeManagerCallback).interfaceId;

    for (uint256 i; i < length; ) {
      register = registers[i];

      _requireHasCode(register);
      _requireSupportsInterface(register, callbackInterface);

      registereds[i] = _callbackRegisters.add(register);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to unregister multiple callbacks from the bridge.
   * @param registers The array of callback addresses to unregister.
   * @return unregistereds An array indicating the success status of each unregistration.
   */
  function _unregisterCallbacks(
    address[] memory registers
  ) internal nonDuplicate(registers) returns (bool[] memory unregistereds) {
    uint256 length = registers.length;
    unregistereds = new bool[](length);
    EnumerableSet.AddressSet storage _callbackRegisters = _getCallbackRegisters();

    for (uint256 i; i < length; ) {
      unregistereds[i] = _callbackRegisters.remove(registers[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to notify all registered callbacks with the provided function signature and data.
   * @param callbackFnSig The function signature of the callback method.
   * @param inputs The data to pass to the callback method.
   */
  function _notifyRegisters(bytes4 callbackFnSig, bytes memory inputs) internal {
    address[] memory registers = _getCallbackRegisters().values();
    uint256 length = registers.length;
    if (length == 0) return;

    bool[] memory successes = new bool[](length);
    bytes[] memory returnDatas = new bytes[](length);
    bytes memory callData = abi.encodePacked(callbackFnSig, inputs);
    bytes memory proxyCallData = abi.encodeCall(TransparentUpgradeableProxyV2.functionDelegateCall, (callData));

    for (uint256 i; i < length; ) {
      (successes[i], returnDatas[i]) = registers[i].call(callData);
      if (!successes[i]) {
        (successes[i], returnDatas[i]) = registers[i].call(proxyCallData);
      }

      unchecked {
        ++i;
      }
    }

    emit Notified(callData, registers, successes, returnDatas);
  }

  /**
   * @dev Internal function to retrieve the address set of callback registers.
   * @return callbackRegisters The storage reference to the callback registers.
   */
  function _getCallbackRegisters() internal pure returns (EnumerableSet.AddressSet storage callbackRegisters) {
    assembly ("memory-safe") {
      callbackRegisters.slot := CALLBACK_REGISTERS_SLOT
    }
  }
}
