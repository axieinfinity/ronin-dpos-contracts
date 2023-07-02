// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IBridgeAdminOperator } from "../../interfaces/IBridgeAdminOperator.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrInvalidVoteWeight, ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

abstract contract BridgeAdminOperator is IBridgeAdminOperator, HasContracts {
  using SafeCast for uint256;
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorToBridgeOperatorInfo.slot") - 1
  bytes32 private constant _GOVERNOR_TO_BRIDGE_OPERATOR_INFO_SLOT =
    0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.govenorOf.slot") - 1
  bytes32 private constant _GOVENOR_OF_SLOT = 0x8400683eb2cb350596d73644c0c89fe45f108600003457374f4ab3e87b4f3aa3;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governors.slot") - 1
  bytes32 private constant _GOVERNOR_SET_SLOT = 0x546f6b46ab35b030b6816596b352aef78857377176c8b24baa2046a62cf1998c;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant _BRIDGE_OPERATOR_SET_SLOT =
    0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;

  uint256 internal _totalWeight;

  modifier nonDuplicate(address[] memory arr) {
    _checkDuplicate(arr);
    _;
  }

  // constructor(
  //   address bridgeContract,
  //   uint256[] memory voteWeights,
  //   address[] memory governors,
  //   address[] memory bridgeOperators
  // ) payable {
  //   // _requireHasCode(bridgeContract);
  // _setContract(ContractType.BRIDGE, bridgeContract);
  // _addBridgeOperators(voteWeights, bridgeOperators, governors);
  // }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function addBridgeOperators(
    uint256[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  )
    external
    onlyContract(ContractType.BRIDGE)
    nonDuplicate(bridgeOperators)
    nonDuplicate(governors)
    returns (bool[] memory addeds)
  {
    addeds = _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlyContract(ContractType.BRIDGE) nonDuplicate(bridgeOperators) returns (bool[] memory removeds) {
    uint256 length = bridgeOperators.length;
    removeds = new bool[](length);

    mapping(address => address) storage governorOf = _governorOf();
    EnumerableSet.AddressSet storage operatorSet = _bridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _governorToBridgeOperatorInfo();

    address governor;
    address bridgeOperator;
    uint256 accumulateWeight;
    BridgeOperatorInfo memory bridgeOperatorInfo;
    for (uint256 i; i < length; ) {
      bridgeOperator = bridgeOperators[i];
      governor = governorOf[bridgeOperator];

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeOperator);

      bridgeOperatorInfo = governorToBridgeOperatorInfo[governor];
      assert(bridgeOperatorInfo.addr == bridgeOperator);
      accumulateWeight += bridgeOperatorInfo.voteWeight;

      if (removeds[i] = operatorSet.remove(bridgeOperator)) {
        delete governorOf[bridgeOperator];
        delete governorToBridgeOperatorInfo[governor];
      }

      unchecked {
        ++i;
      }
    }

    _totalWeight -= accumulateWeight;

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Remove);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function updateBridgeOperator(address newBridgeOperator) external returns (bool updated) {
    _checkNonZeroAddress(newBridgeOperator);

    EnumerableSet.AddressSet storage operatorSet = _bridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage gorvernorToBridgeVoter = _governorToBridgeOperatorInfo();

    address currentBridgeOperator = gorvernorToBridgeVoter[msg.sender].addr;

    // return false if currentBridgeOperator unexists in operatorSet
    if (!operatorSet.remove(currentBridgeOperator)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }

    gorvernorToBridgeVoter[msg.sender].addr = newBridgeOperator;

    updated = operatorSet.add(newBridgeOperator);

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getTotalWeights() external view returns (uint256) {
    return _totalWeight;
  }

  function getBridgeVoterWeight(address governor) external view returns (uint256) {
    return _governorToBridgeOperatorInfo()[governor].voteWeight;
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeVoterWeights(address[] calldata governors) external view returns (uint256[] memory weights) {
    uint256 length = governors.length;
    weights = new uint256[](length);
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _governorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      weights[i] = governorToBridgeOperatorInfo[governors[i]].voteWeight;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getSumBridgeVoterWeights(
    address[] memory governors
  ) public view nonDuplicate(governors) returns (uint256 sum) {
    uint256 length = _bridgeOperatorSet().length();
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _governorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      sum += governorToBridgeOperatorInfo[governors[i]].voteWeight;

      unchecked {
        ++i;
      }
    }
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

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getGovernors() external view returns (address[] memory) {
    return _governorsSet().values();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeOperatorOf(address[] calldata governors) external view returns (address[] memory bridgeOperators_) {
    uint256 length = governors.length;
    bridgeOperators_ = new address[](length);

    mapping(address => BridgeOperatorInfo) storage gorvernorToBridgeOperator = _governorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      bridgeOperators_[i] = gorvernorToBridgeOperator[governors[i]].addr;
      unchecked {
        ++i;
      }
    }
  }

  function _addBridgeOperators(
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory brigdeOperators
  ) internal returns (bool[] memory addeds) {
    uint256 length = brigdeOperators.length;
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage governorSet = _governorsSet();
    mapping(address => address) storage governorOf = _governorOf();
    EnumerableSet.AddressSet storage bridgeOperatorSet = _bridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _governorToBridgeOperatorInfo();

    address governor;
    uint96 voteWeight;
    address bridgeOperator;
    uint256 accumulateWeight;
    BridgeOperatorInfo memory bridgeOperatorInfo;
    for (uint256 i; i < length; ) {
      governor = governors[i];
      bridgeOperator = brigdeOperators[i];
      voteWeight = voteWeights[i].toUint96();

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeOperator);
      _sanityCheck(voteWeight, governor, bridgeOperator);

      addeds[i] = bridgeOperatorSet.add(bridgeOperator);

      unchecked {
        if (addeds[i]) {
          governorSet.add(governor);

          accumulateWeight += voteWeight;

          governorOf[bridgeOperator] = governor;

          bridgeOperatorInfo.addr = bridgeOperator;
          bridgeOperatorInfo.voteWeight = voteWeight;
          governorToBridgeOperatorInfo[governor] = bridgeOperatorInfo;
        }
        ++i;
      }
    }

    _totalWeight += accumulateWeight;

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Add);
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _bridgeOperatorSet() internal pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := _BRIDGE_OPERATOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return governors_ the storage address set.
   */
  function _governorsSet() internal pure returns (EnumerableSet.AddressSet storage governors_) {
    assembly {
      governors_.slot := _GOVERNOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from governor => BridgeOperatorInfo.
   * @return governorToBridgeOperatorInfo_ the mapping from governor => BridgeOperatorInfo.
   */
  function _governorToBridgeOperatorInfo()
    internal
    pure
    returns (mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo_)
  {
    assembly {
      governorToBridgeOperatorInfo_.slot := _GOVERNOR_TO_BRIDGE_OPERATOR_INFO_SLOT
    }
  }

  function _governorOf() internal pure returns (mapping(address => address) storage govenorOf_) {
    assembly {
      govenorOf_.slot := _GOVENOR_OF_SLOT
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
