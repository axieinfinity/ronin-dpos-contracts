// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { IBridgeAdmin } from "../../interfaces/IBridgeAdmin.sol";
import { ErrLengthMismatch, ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";

contract BridgeAdmin is IBridgeAdmin, HasContracts, Initializable {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableMap for EnumerableMap.UintToAddressMap;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.secondaryWallets.slot") - 1
  bytes32 private constant _SECONDARY_WALLET_SLOT = 0xe9c86f17b6b2ca648c0941f1294df733252a0665d280ed3a951a89b79916d785;

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
    address[] calldata bridgeOperators,
    address[] calldata secondaryWallets
  ) external initializer nonDuplicate(bridgeOperators) {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
    _addBridgeOperators(bridgeOperators, secondaryWallets);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function addBridgeOperators(
    address[] calldata bridgeOperators,
    address[] calldata secondaryWallets
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeOperators) returns (bool[] memory addeds) {
    addeds = _addBridgeOperators(bridgeOperators, secondaryWallets);
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
  function updateBridgeOperator(address newBridgeOperator) external returns (bool updated) {
    _checkNonZeroAddress(newBridgeOperator);

    address currentBridgeOperator = _bridgeOperators().contains(msg.sender)
      ? msg.sender
      : _secondaryWallets().contains(uint160(msg.sender))
      ? _secondaryWallets().get(uint160(msg.sender))
      : address(0);

    if (!_bridgeOperators().contains(currentBridgeOperator)) {
      //   _secondaryWallets().remove(uint160(msg.sender));
      //   return;
      revert ErrUnauthorized(msg.sig, RoleAccess.__DEPRECATED_BRIDGE_OPERATOR);
    }

    updated = _updateBridgeOperator(currentBridgeOperator, newBridgeOperator);

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

  function getSecondaryWallets() external view returns (address[] memory secondaryWallets_) {
    uint256[] memory secondaryWallets = _secondaryWallets().keys();
    assembly {
      secondaryWallets_ := secondaryWallets
    }
  }

  function _updateBridgeOperator(address fromAddress, address toAddress) internal returns (bool updated) {
    _bridgeOperators().remove(fromAddress);
    updated = _bridgeOperators().add(toAddress);
  }

  function _addBridgeOperators(
    address[] calldata bridgeOperators,
    address[] calldata secondaryWallets
  ) internal returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    if (length != secondaryWallets.length) revert ErrLengthMismatch(msg.sig);
    addeds = new bool[](length);
    EnumerableMap.UintToAddressMap storage walletSet = _secondaryWallets();
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperators();
    for (uint256 i; i < length; ) {
      _checkNonZeroAddress(bridgeOperators[i]);
      _checkNonZeroAddress(secondaryWallets[i]);

      walletSet.set(uint160(secondaryWallets[i]), bridgeOperators[i]);
      addeds[i] = operatorSet.add(bridgeOperators[i]);
      unchecked {
        ++i;
      }
    }
    emit OperatorSetModified(msg.sender, BridgeAction.Add);
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

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _bridgeOperators() private pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := _BRIDGE_OPERATORS_SLOT
    }
  }

  function _secondaryWallets() private pure returns (EnumerableMap.UintToAddressMap storage secondaryWallets) {
    assembly {
      secondaryWallets.slot := _SECONDARY_WALLET_SLOT
    }
  }
}
