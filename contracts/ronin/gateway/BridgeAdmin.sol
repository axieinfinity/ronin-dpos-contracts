// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeAdmin } from "../../interfaces/IBridgeAdmin.sol";
import { ErrUnauthorized } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";

contract BridgeAdmin is IBridgeAdmin, HasContracts, Initializable {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;

  function initialize(address bridgeContract) external initializer {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function addBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    addeds = new bool[](length);
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    for (uint256 i; i < length; ) {
      addeds[i] = operatorSet.add(bridgeOperators[i]);
      unchecked {
        ++i;
      }
    }
    emit OperatorSetModified(msg.sender, BridgeAction.Add);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) returns (bool[] memory removeds) {
    uint256 length = bridgeOperators.length;
    removeds = new bool[](length);
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    for (uint256 i; i < length; ) {
      removeds[i] = operatorSet.remove(bridgeOperators[i]);
      unchecked {
        ++i;
      }
    }
    emit OperatorSetModified(msg.sender, BridgeAction.Remove);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function updateBridgeOperator(address bridgeOperator) external returns (bool updated) {
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    if (!operatorSet.remove(msg.sender)) revert ErrUnauthorized(msg.sig, RoleAccess.__DEPRECATED_BRIDGE_OPERATOR);
    updated = operatorSet.add(bridgeOperator);
    emit OperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _bridgeOperators().length();
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _bridgeOperators().contains(addr);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function getBridgeOperators() external view returns (address[] memory) {
    return _bridgeOperators().values();
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _bridgeOperators() private pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := _BRIDGE_OPERATORS_SLOT
    }
  }
}
