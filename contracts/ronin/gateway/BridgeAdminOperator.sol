// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { IBridgeAdminOperator } from "../../interfaces/IBridgeAdminOperator.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrInvalidVoteWeight, ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

abstract contract BridgeAdminOperator is IBridgeAdminOperator, HasContracts {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperatorInfo.slot") - 1
  bytes32 private constant _BRIDGE_OPERATOR_INFO_SLOT =
    0xe2e718851bb1c8eb99cbf923ff339c5e8aedd92e3d23c286f2024724214cbfc3;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorToBridgeOperator.slot") - 1
  bytes32 private constant _GOVERNOR_TO_BRIDGE_OPERATOR_SLOT =
    0x036a0f8f5d3a4b80818dc282d4074f198396f885ba62102afe6d872c11427adc;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATORS_SLOT = 0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorset.slot") - 1
  bytes32 private constant _GOVERNOR_SET_SLOT = 0xee9a62453083ffc23e824959c176ce9a249e593eb4614183dd0c790be089488c;

  uint256 internal _totalWeight;

  modifier nonDuplicate(address[] calldata arr) {
    _checkDuplicate(arr);
    _;
  }

  constructor(
    address bridgeContract,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable {
    // _requireHasCode(bridgeContract);
    _setContract(ContractType.BRIDGE, bridgeContract);
    _addBridgeOperators(voteWeights, bridgeOperators, governors);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function addBridgeOperators(
    uint256[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeVoters
  )
    external
    onlyContract(ContractType.BRIDGE)
    nonDuplicate(bridgeVoters)
    nonDuplicate(governors)
    returns (bool[] memory addeds)
  {
    addeds = _addBridgeOperators(voteWeights, bridgeVoters, governors);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function removeBridgeOperators(
    address[] calldata bridgeVoters
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeVoters) returns (bool[] memory removeds) {
    uint256 length = bridgeVoters.length;
    removeds = new bool[](length);

    EnumerableSet.AddressSet storage operatorSet = _bridgeVoterSet();
    mapping(address => address) storage governorToBridgeVoter = _gorvernorToBridgeVoter();
    mapping(address => BridgeOperator) storage bridgeOperatorInfo = _bridgeOperatorInfo();

    address bridgeVoter;
    uint256 accumulateWeight;
    BridgeOperator memory bridgeOperator;
    for (uint256 i; i < length; ) {
      bridgeVoter = bridgeVoters[i];

      _checkNonZeroAddress(bridgeVoter);

      bridgeOperator = bridgeOperatorInfo[bridgeVoter];
      accumulateWeight += bridgeOperator.voteWeight;

      removeds[i] = operatorSet.remove(bridgeVoter);
      delete bridgeOperatorInfo[bridgeVoter];
      delete governorToBridgeVoter[bridgeOperator.gorvernor];

      unchecked {
        ++i;
      }
    }

    _totalWeight -= accumulateWeight;

    emit OperatorSetModified(msg.sender, BridgeAction.Remove);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function updateBridgeOperator(address newBridgeVoter) external returns (bool updated) {
    _checkNonZeroAddress(newBridgeVoter);

    EnumerableSet.AddressSet storage operatorSet = _bridgeVoterSet();
    mapping(address => BridgeOperator) storage bridgeOperatorInfo = _bridgeOperatorInfo();
    mapping(address => address) storage gorvernorToBridgeVoter = _gorvernorToBridgeVoter();

    address currentBridgeVoter = gorvernorToBridgeVoter[msg.sender];

    // return false if currentBridgeVoter unexists in operatorSet
    if (!operatorSet.remove(currentBridgeVoter)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }

    // copy old bridge operator info
    bridgeOperatorInfo[newBridgeVoter] = bridgeOperatorInfo[currentBridgeVoter];
    // delete old bridge operator info
    delete bridgeOperatorInfo[currentBridgeVoter];

    updated = operatorSet.add(newBridgeVoter);
    gorvernorToBridgeVoter[msg.sender] = newBridgeVoter;

    emit OperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _bridgeVoterSet().length();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _bridgeVoterSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeOperators() external view returns (address[] memory) {
    return _bridgeVoterSet().values();
  }

  function getGovernors() external view returns (address[] memory) {
    return _governors().values();
  }

  function getBridgeOperatorOf(address[] calldata governors) external view returns (address[] memory bridgeOperators_) {
    uint256 length = governors.length;
    bridgeOperators_ = new address[](length);
    mapping(address => address) storage gorvernorToBridgeOperator = _gorvernorToBridgeVoter();
    for (uint256 i; i < length; ) {
      bridgeOperators_[i] = gorvernorToBridgeOperator[governors[i]];
      unchecked {
        ++i;
      }
    }
  }

  function _addBridgeOperators(
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeVoters
  ) private returns (bool[] memory addeds) {
    uint256 length = bridgeVoters.length;
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage governorset = _governors();
    EnumerableSet.AddressSet storage bridgeVoterSet = _bridgeVoterSet();
    mapping(address => BridgeOperator) storage bridgeOperatorInfo = _bridgeOperatorInfo();
    mapping(address => address) storage gorvernorToBridgeVoter = _gorvernorToBridgeVoter();

    address governor;
    uint96 voteWeight;
    address bridgeVoter;
    uint256 accumulateWeight;
    for (uint256 i; i < length; ) {
      governor = governors[i];
      bridgeVoter = bridgeVoters[i];
      voteWeight = uint96(voteWeights[i]);

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeVoter);
      _sanityCheck(voteWeight, governor, bridgeVoter);

      addeds[i] = bridgeVoterSet.add(bridgeVoter);

      unchecked {
        if (addeds[i]) {
          governorset.add(governor);
          accumulateWeight += voteWeight;
          gorvernorToBridgeVoter[governor] = bridgeVoter;
          bridgeOperatorInfo[bridgeVoter] = BridgeOperator(governor, voteWeight);
        }
        ++i;
      }
    }

    _totalWeight += accumulateWeight;

    emit OperatorSetModified(msg.sender, BridgeAction.Add);
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _bridgeVoterSet() internal pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
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
  function _gorvernorToBridgeVoter() private pure returns (mapping(address => address) storage bridgeOperators_) {
    assembly {
      bridgeOperators_.slot := _BRIDGE_OPERATORS_SLOT
    }
  }

  function _bridgeOperatorInfo()
    internal
    pure
    returns (mapping(address => BridgeOperator) storage bridgeOperatorInfo_)
  {
    assembly {
      bridgeOperatorInfo_.slot := _BRIDGE_OPERATOR_INFO_SLOT
    }
  }

  /**
   * @dev Check if arr is empty and revert if it is.
   * Checks if an array contains any duplicate addresses and reverts if duplicates are found.
   * @param arr The array of addresses to check.
   */
  function _checkDuplicate(address[] memory arr) internal pure {
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

  function _sanityCheck(uint256 voteWeight, address governor, address bridgeOperator) private pure {
    if (voteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);

    address[] memory addrs = new address[](2);
    addrs[0] = governor;
    addrs[1] = bridgeOperator;

    _checkDuplicate(addrs);
  }
}
