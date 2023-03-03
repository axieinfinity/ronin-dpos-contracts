// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBridgeTracking.sol";
import "../interfaces/collections/IHasBridgeTrackingContract.sol";

contract MockGatewayForTracking is IHasBridgeTrackingContract {
  /// @dev The bridge tracking contract
  IBridgeTracking internal _bridgeTrackingContract;

  constructor(address __bridgeTrackingContract) {
    _setBridgeTrackingContract(__bridgeTrackingContract);
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function bridgeTrackingContract() external view returns (address) {
    return address(_bridgeTrackingContract);
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function setBridgeTrackingContract(address _addr) external {
    require(_addr.code.length > 0, "RoninGatewayV2: set to non-contract");
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

  function sendBallot(IBridgeTracking.Request memory _request, address _voter) external {
    _bridgeTrackingContract.recordVote(_request.kind, _request.id, _voter);
  }

  function sendApprovedVote(IBridgeTracking.Request memory _request) external {
    _bridgeTrackingContract.handleVoteApproved(_request.kind, _request.id);
  }
}
