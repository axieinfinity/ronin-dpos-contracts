// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { IBridgeAdmin } from "../../interfaces/IBridgeAdmin.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

contract BridgeAdmin is IBridgeAdmin, HasContracts, Initializable {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.authAccountSet.slot") - 1
  bytes32 private constant _AUTH_ACCOUNT_SET_SLOT = 0xee9a62453083ffc23e824959c176ce9a249e593eb4614183dd0c790be089488c;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperatorSet.slot") - 1
  bytes32 private constant _BRIDGE_OPERATOR_SET_SLOT =
    0xfa6942bcd0cb9618731a0b9eaab9fd34c6d6385aa2aac7d7040156273bdde72c;

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
    address[] calldata authAccounts,
    address[] calldata bridgeOperators
  ) external initializer nonDuplicate(bridgeOperators) nonDuplicate(authAccounts) {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
    _addBridgeOperators(bridgeOperators, authAccounts);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function addBridgeOperators(
    address[] calldata authAccounts,
    address[] calldata bridgeOperators
  )
    external
    onlyContract(ContractType.BRIDGE)
    nonDuplicate(bridgeOperators)
    nonDuplicate(authAccounts)
    returns (bool[] memory addeds)
  {
    addeds = _addBridgeOperators(bridgeOperators, authAccounts);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeOperators) returns (bool[] memory removeds) {
    uint256 length = bridgeOperators.length;
    removeds = new bool[](length);
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperatorSet();

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

    mapping(address => BridgeOperator) storage bridgeOperatorMap = _bridgeOperators();
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperatorSet();
    address currentBridgeOperator = bridgeOperatorMap[msg.sender].addr;

    // return false if currentBridgeOperator unexists in operatorSet
    if (!operatorSet.remove(currentBridgeOperator)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.__DEPRECATED_BRIDGE_OPERATOR);
    }

    updated = operatorSet.add(newBridgeOperator);

    emit OperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _bridgeOperatorSet().length();
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _bridgeOperatorSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeAdmin
   */
  function getBridgeOperators() external view returns (address[] memory) {
    return _bridgeOperatorSet().values();
  }

  function _addBridgeOperators(
    address[] calldata authAccounts,
    address[] calldata bridgeOperators
  ) private returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage authAccountSet = _authAccounts();
    EnumerableSet.AddressSet storage bridgeOperatorSet = _bridgeOperatorSet();
    mapping(address => BridgeOperator) storage bridgeOperatorMap = _bridgeOperators();

    address authAccount;
    address bridgeOperator;

    for (uint256 i; i < length; ) {
      authAccount = authAccounts[i];
      bridgeOperator = bridgeOperators[i];

      _checkNonZeroAddress(authAccount);
      _checkNonZeroAddress(bridgeOperator);

      addeds[i] = bridgeOperatorSet.add(bridgeOperator);

      unchecked {
        if (addeds[i]) {
          authAccountSet.add(authAccount);
          bridgeOperatorMap[authAccount].addr = bridgeOperator;
        }
        ++i;
      }
    }

    emit OperatorSetModified(msg.sender, BridgeAction.Add);
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _bridgeOperatorSet() private pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := _BRIDGE_OPERATOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return authAccounts_ the storage address set.
   */
  function _authAccounts() private pure returns (EnumerableSet.AddressSet storage authAccounts_) {
    assembly {
      authAccounts_.slot := _AUTH_ACCOUNT_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from auth account => BridgeOperator.
   * @return bridgeOperators_ the storage address set.
   */
  function _bridgeOperators() private pure returns (mapping(address => BridgeOperator) storage bridgeOperators_) {
    assembly {
      bridgeOperators_.slot := _BRIDGE_OPERATORS_SLOT
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
