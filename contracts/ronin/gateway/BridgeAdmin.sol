// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { IBridgeAdmin } from "../../interfaces/IBridgeAdmin.sol";
import { ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";

contract BridgeAdmin is IBridgeAdmin, HasContracts, Initializable {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;

  modifier nonDuplicate(address[] calldata arr) {
    _checkDuplicate(arr);
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address bridgeContract,
    address[] calldata bridgeOperators
  ) external initializer nonDuplicate(bridgeOperators) {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
    _addBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function addBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeOperators) returns (bool[] memory addeds) {
    addeds = _addBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeOperators) returns (bool[] memory removeds) {
    uint256 length = bridgeOperators.length;
    removeds = new bool[](length);
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    for (uint256 i; i < length; ) {
      _checkNonZeroAddress(bridgeOperators[i]);
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
    _checkNonZeroAddress(bridgeOperator);
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

  function _addBridgeOperators(address[] calldata bridgeOperators) internal returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    addeds = new bool[](length);
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    for (uint256 i; i < length; ) {
      _checkNonZeroAddress(bridgeOperators[i]);
      addeds[i] = operatorSet.add(bridgeOperators[i]);
      unchecked {
        ++i;
      }
    }
    emit OperatorSetModified(msg.sender, BridgeAction.Add);
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

  /**
   * @dev Check if arr is empty and revert if it is.
   * Checks if an array contains any duplicate addresses and reverts if duplicates are found.
   * @param arr The array of addresses to check.
   */
  function _checkDuplicate(address[] calldata arr) private pure {
    if (arr.length == 0) revert ErrEmptyArray();
    if (arr.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }

  /**
   * @dev Checks if an address is zero and reverts if it is.
   * @param addr The address to check.
   */
  function _checkNonZeroAddress(address addr) private pure {
    if (addr == address(0)) revert ErrZeroAddress(msg.sig);
  }
}
