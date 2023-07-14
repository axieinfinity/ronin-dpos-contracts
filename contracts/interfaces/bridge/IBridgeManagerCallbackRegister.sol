// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeManagerCallbackRegister {
  /**
   * @dev Registers multiple callbacks with the bridge.
   * @param registers The array of callback addresses to register.
   * @return registereds An array indicating the success status of each registration.
   */
  function registerCallbacks(address[] calldata registers) external returns (bool[] memory registereds);

  /**
   * @dev Unregisters multiple callbacks from the bridge.
   * @param registers The array of callback addresses to unregister.
   * @return unregistereds An array indicating the success status of each unregistration.
   */
  function unregisterCallbacks(address[] calldata registers) external returns (bool[] memory unregistereds);
}
