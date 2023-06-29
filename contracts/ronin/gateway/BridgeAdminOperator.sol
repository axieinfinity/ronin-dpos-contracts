// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { IBridgeAdminOperator } from "../../interfaces/IBridgeAdminOperator.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

abstract contract BridgeAdminOperator is IBridgeAdminOperator, HasContracts {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorToBridgeOperator.slot") - 1
  bytes32 private constant _GOVERNOR_TO_BRIDGE_OPERATOR_SLOT =
    0x036a0f8f5d3a4b80818dc282d4074f198396f885ba62102afe6d872c11427adc;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorset.slot") - 1
  bytes32 private constant _GOVERNOR_SET_SLOT = 0xee9a62453083ffc23e824959c176ce9a249e593eb4614183dd0c790be089488c;

  modifier nonDuplicate(address[] calldata arr) {
    _checkDuplicate(arr);
    _;
  }

  constructor(address bridgeContract, address[] memory governors, address[] memory bridgeOperators) payable {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
    _addBridgeOperators(bridgeOperators, governors);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function addBridgeOperators(
    address[] calldata governors,
    address[] calldata bridgeOperators
  )
    external
    onlyContract(ContractType.BRIDGE)
    nonDuplicate(bridgeOperators)
    nonDuplicate(governors)
    returns (bool[] memory addeds)
  {
    addeds = _addBridgeOperators(bridgeOperators, governors);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
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
   * @inheritdoc IBridgeAdminOperator
   */
  function updateBridgeOperator(address newBridgeOperator) external returns (bool updated) {
    _checkNonZeroAddress(newBridgeOperator);

    mapping(address => address) storage bridgeOperatorMap = _bridgeOperators();
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperatorSet();
    address currentBridgeOperator = bridgeOperatorMap[msg.sender];

    // return false if currentBridgeOperator unexists in operatorSet
    if (!operatorSet.remove(currentBridgeOperator)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }

    updated = operatorSet.add(newBridgeOperator);

    emit OperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _bridgeOperatorSet().length();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _bridgeOperatorSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeOperators() external view returns (address[] memory) {
    return _bridgeOperatorSet().values();
  }

  function getGovernors() external view returns (address[] memory) {
    return _governors().values();
  }

  function getBridgeOperatorOf(address[] calldata governors) external view returns (address[] memory bridgeOperators_) {
    uint256 length = governors.length;
    bridgeOperators_ = new address[](length);
    mapping(address => address) storage bridgeOperatorMap = _bridgeOperators();
    for (uint256 i; i < length; ) {
      bridgeOperators_[i] = bridgeOperatorMap[governors[i]];
      unchecked {
        ++i;
      }
    }
  }

  function _addBridgeOperators(
    address[] memory governors,
    address[] memory bridgeOperators
  ) private returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage governorset = _governors();
    EnumerableSet.AddressSet storage bridgeOperatorSet = _bridgeOperatorSet();
    mapping(address => address) storage bridgeOperatorMap = _bridgeOperators();

    address governor;
    address bridgeOperator;

    for (uint256 i; i < length; ) {
      governor = governors[i];
      bridgeOperator = bridgeOperators[i];

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeOperator);

      addeds[i] = bridgeOperatorSet.add(bridgeOperator);

      unchecked {
        if (addeds[i]) {
          governorset.add(governor);
          bridgeOperatorMap[governor] = bridgeOperator;
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
  function _bridgeOperatorSet() internal pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := _GOVERNOR_TO_BRIDGE_OPERATOR_SLOT
    }
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return governors_ the storage address set.
   */
  function _governors() internal pure returns (EnumerableSet.AddressSet storage governors_) {
    assembly {
      governors_.slot := _GOVERNOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from auth account => BridgeOperator.
   * @return bridgeOperators_ the storage address set.
   */
  function _bridgeOperators() private pure returns (mapping(address => address) storage bridgeOperators_) {
    assembly {
      bridgeOperators_.slot := _BRIDGE_OPERATORS_SLOT
    }
  }

  /**
   * @dev Check if arr is empty and revert if it is.
   * Checks if an array contains any duplicate addresses and reverts if duplicates are found.
   * @param arr The array of addresses to check.
   */
  function _checkDuplicate(address[] calldata arr) internal pure {
    if (arr.length == 0) revert ErrEmptyArray();
    if (arr.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }

  /**
   * @dev Checks if an address is zero and reverts if it is.
   * @param addr The address to check.
   */
  function _checkNonZeroAddress(address addr) internal pure {
    if (addr == address(0)) revert ErrZeroAddress(msg.sig);
  }
}
