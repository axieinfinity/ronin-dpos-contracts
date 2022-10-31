// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasBridgeTrackingContract.sol";
import "../../interfaces/IBridgeTracking.sol";

contract HasBridgeTrackingContract is IHasBridgeTrackingContract, HasProxyAdmin {
  IBridgeTracking internal _bridgeTrackingContract;

  modifier onlyBridgeTrackingContract() {
    require(
      bridgeTrackingContract() == msg.sender,
      "HasBridgeTrackingContract: method caller must be bridge tracking contract"
    );
    _;
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function bridgeTrackingContract() public view override returns (address) {
    return address(_bridgeTrackingContract);
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function setBridgeTrackingContract(address _addr) external virtual override onlyAdmin {
    _setBridgeTrackingContract(_addr);
  }

  /**
   * @dev Sets the bridge tracking contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `BridgeTrackingContractUpdated`.
   *
   */
  function _setBridgeTrackingContract(address _addr) internal {
    _bridgeTrackingContract = IBridgeTracking(_addr);
    emit BridgeTrackingContractUpdated(_addr);
  }
}
