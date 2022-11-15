// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasBridgeContract.sol";
import "../../interfaces/IBridge.sol";

contract HasBridgeContract is IHasBridgeContract, HasProxyAdmin {
  IBridge internal _bridgeContract;

  modifier onlyBridgeContract() {
    require(bridgeContract() == msg.sender, "HasBridgeContract: method caller must be bridge contract");
    _;
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
    require(_addr.code.length > 0, "HasBridgeContract: set to non-contract");
    _setBridgeContract(_addr);
  }

  /**
   * @dev Sets the bridge contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `BridgeContractUpdated`.
   *
   */
  function _setBridgeContract(address _addr) internal {
    _bridgeContract = IBridge(_addr);
    emit BridgeContractUpdated(_addr);
  }
}
