// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasBridgeContract.sol";
import "../../interfaces/IBridge.sol";

contract HasBridgeContract is IHasBridgeContract, HasProxyAdmin {
  IBridge internal _bridgeContract;

  modifier onlyBridgeContract() {
    _requireBridgeContract();
    _;
  }

  function _requireBridgeContract() private view {
    if (bridgeContract() != msg.sender) revert ErrUnauthorized(msg.sig, Roles.BRIDGE);
  }

  /**
   * @inheritdoc IHasBridgeContract
   */
  function bridgeContract() public view override returns (address) {
    return address(_bridgeContract);
  }

  /**
   * @inheritdoc IHasBridgeContract
   */
  function setBridgeContract(address _addr) external virtual override onlyAdmin {
    if (_addr.code.length <= 0) revert ErrZeroCodeContract(msg.sig);
    _setBridgeContract(_addr);
  }

  /**
   * @dev Sets the bridge contract.
   *
   * Emits the event `BridgeContractUpdated`.
   *
   */
  function _setBridgeContract(address _addr) internal {
    _bridgeContract = IBridge(_addr);
    emit BridgeContractUpdated(_addr);
  }
}
