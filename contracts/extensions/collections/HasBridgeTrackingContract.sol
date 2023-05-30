// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasBridgeTrackingContract.sol";
import "../../interfaces/IBridgeTracking.sol";

contract HasBridgeTrackingContract is IHasBridgeTrackingContract, HasProxyAdmin {
  IBridgeTracking internal _bridgeTrackingContract;

  modifier onlyBridgeTrackingContract() {
    if (bridgeTrackingContract() != msg.sender) revert ErrUnauthorized(msg.sig, Roles.BRIDGE_TRACKING_CONTRACT);
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
    if (_addr.code.length == 0) revert ErrZeroCodeContract(msg.sig);
    _setBridgeTrackingContract(_addr);
  }

  /**
   * @dev Sets the bridge tracking contract.
   *
   * Emits the event `BridgeTrackingContractUpdated`.
   *
   */
  function _setBridgeTrackingContract(address _addr) internal {
    _bridgeTrackingContract = IBridgeTracking(_addr);
    emit BridgeTrackingContractUpdated(_addr);
  }
}
