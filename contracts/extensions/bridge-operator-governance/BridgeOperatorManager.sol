// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IBridgeOperatorManager } from "../../interfaces/IBridgeOperatorManager.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrOnlySelfCall, ErrInvalidArguments, ErrLengthMismatch, ErrInvalidThreshold, ErrInvalidVoteWeight, ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

abstract contract BridgeOperatorManager is IQuorum, IBridgeOperatorManager, HasContracts {
  using SafeCast for uint256;
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin._governorToBridgeOperatorInfo.slot") - 1
  bytes32 private constant GOVERNOR_TO_BRIDGE_OPERATOR_INFO_SLOT =
    0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.govenorOf.slot") - 1
  bytes32 private constant GOVENOR_OF_SLOT = 0x8400683eb2cb350596d73644c0c89fe45f108600003457374f4ab3e87b4f3aa3;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governors.slot") - 1
  bytes32 private constant GOVERNOR_SET_SLOT = 0x546f6b46ab35b030b6816596b352aef78857377176c8b24baa2046a62cf1998c;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.bridgeOperators.slot") - 1
  bytes32 private constant BRIDGE_OPERATOR_SET_SLOT =
    0xd38c234075fde25875da8a6b7e36b58b86681d483271a99eeeee1d78e258a24d;

  /**
   * @dev The domain separator used for computing hash digests in the contract.
   */
  bytes32 public immutable DOMAIN_SEPARATOR;

  /**
   * @dev The numerator value used for calculations in the contract.
   */
  uint256 internal _num;

  /**
   * @dev The denominator value used for calculations in the contract.
   */
  uint256 internal _denom;

  /**
   * @dev The nonce value used for tracking nonces in the contract.
   */
  uint256 internal _nonce;

  /**
   * @dev The total weight value used for storing the cumulative weight in the contract.
   */
  uint256 internal _totalWeight;

  modifier onlySelfCall() {
    _requireSelfCall();
    _;
  }

  /**
   * @dev Modifier to ensure that the elements in the `arr` array are non-duplicates.
   * It calls the internal `_checkDuplicate` function to perform the duplicate check.
   *
   * Requirements:
   * - The elements in the `arr` array must not contain any duplicates.
   */
  modifier nonDuplicate(address[] memory arr) {
    _checkDuplicate(arr);
    _;
  }

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address admin,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable nonDuplicate(governors) nonDuplicate(bridgeOperators) {
    _checkNonZeroAddress(admin);
    assembly {
      sstore(_ADMIN_SLOT, admin)
    }

    _nonce = 1;
    _num = num;
    _denom = denom;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", roninChainId)) // salt
      )
    );

    _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function addBridgeOperators(
    uint256[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  ) external onlySelfCall nonDuplicate(bridgeOperators) nonDuplicate(governors) returns (bool[] memory addeds) {
    addeds = _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlySelfCall returns (bool[] memory removeds) {
    return _removeBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function updateBridgeOperator(address newBridgeOperator) external returns (bool updated) {
    _checkNonZeroAddress(newBridgeOperator);

    mapping(address => address) storage _governorOf = _getGovernorOf();
    EnumerableSet.AddressSet storage _bridgeOperatorSet = _getBridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage _gorvernorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    BridgeOperatorInfo memory bridgeOperatorInfo = _gorvernorToBridgeOperatorInfo[msg.sender];
    address currentBridgeOperator = bridgeOperatorInfo.addr;

    // return false if currentBridgeOperator unexists in _bridgeOperatorSet
    if (!_bridgeOperatorSet.remove(currentBridgeOperator)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }
    updated = _bridgeOperatorSet.add(newBridgeOperator);

    bridgeOperatorInfo.addr = newBridgeOperator;
    _gorvernorToBridgeOperatorInfo[msg.sender] = bridgeOperatorInfo;
    _governorOf[newBridgeOperator] = msg.sender;

    delete _governorOf[currentBridgeOperator];

    bool[] memory statuses = new bool[](1);
    statuses[0] = updated;

    emit BridgeOperatorUpdated(msg.sender, currentBridgeOperator, newBridgeOperator);
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 numerator, uint256 denominator) external override onlyAdmin returns (uint256, uint256) {
    return _setThreshold(numerator, denominator);
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getTotalWeights() external view returns (uint256) {
    return _totalWeight;
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getBridgeVoterWeight(address governor) external view returns (uint256) {
    return _getGovernorToBridgeOperatorInfo()[governor].voteWeight;
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getBridgeVoterWeights(address[] calldata governors) external view returns (uint256[] memory weights) {
    uint256 length = governors.length;
    weights = new uint256[](length);
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      weights[i] = _governorToBridgeOperatorInfo[governors[i]].voteWeight;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getSumBridgeVoterWeights(
    address[] memory governors
  ) public view nonDuplicate(governors) returns (uint256 sum) {
    uint256 length = _getBridgeOperatorSet().length();
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      sum += _governorToBridgeOperatorInfo[governors[i]].voteWeight;

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _getBridgeOperatorSet().length();
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _getBridgeOperatorSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getBridgeOperators() public view returns (address[] memory) {
    return _getBridgeOperatorSet().values();
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getGovernors() external view returns (address[] memory) {
    return _getGovernorsSet().values();
  }

  /**
   * @inheritdoc IBridgeOperatorManager
   */
  function getBridgeOperatorOf(address[] calldata governors) external view returns (address[] memory bridgeOperators_) {
    uint256 length = governors.length;
    bridgeOperators_ = new address[](length);

    mapping(address => BridgeOperatorInfo) storage _gorvernorToBridgeOperator = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      bridgeOperators_[i] = _gorvernorToBridgeOperator[governors[i]].addr;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @dev Internal function to add bridge operators.
   *
   * This function adds the specified `bridgeOperators` to the bridge operator set and establishes the associated mappings.
   *
   * Requirements:
   * - The caller must have the necessary permission to add bridge operators.
   * - The lengths of `voteWeights`, `governors`, and `bridgeOperators` arrays must be equal.
   *
   * @param voteWeights An array of uint256 values representing the vote weights for each bridge operator.
   * @param governors An array of addresses representing the governors for each bridge operator.
   * @return addeds An array of boolean values indicating whether each bridge operator was successfully added.
   */
  function _addBridgeOperators(
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory brigdeOperators
  ) internal returns (bool[] memory addeds) {
    uint256 length = brigdeOperators.length;
    if (!(length == voteWeights.length && length == governors.length)) revert ErrLengthMismatch(msg.sig);
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage _governorSet = _getGovernorsSet();
    mapping(address => address) storage _governorOf = _getGovernorOf();
    EnumerableSet.AddressSet storage bridgeOperatorSet = _getBridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();

    // get rid of stack too deep
    uint256 accumulatedWeight;
    {
      address governor;
      uint96 voteWeight;
      address bridgeOperator;
      BridgeOperatorInfo memory bridgeOperatorInfo;

      for (uint256 i; i < length; ) {
        governor = governors[i];
        bridgeOperator = brigdeOperators[i];
        voteWeight = voteWeights[i].toUint96();

        _checkNonZeroAddress(governor);
        _checkNonZeroAddress(bridgeOperator);
        _sanityCheck(voteWeight, governor, bridgeOperator);

        addeds[i] = bridgeOperatorSet.add(bridgeOperator);

        if (addeds[i]) {
          _governorSet.add(governor);

          accumulatedWeight += voteWeight;

          _governorOf[bridgeOperator] = governor;

          bridgeOperatorInfo.addr = bridgeOperator;
          bridgeOperatorInfo.voteWeight = voteWeight;
          _governorToBridgeOperatorInfo[governor] = bridgeOperatorInfo;
        }

        unchecked {
          ++i;
        }
      }
    }

    _totalWeight += accumulatedWeight;

    emit BridgeOperatorsAdded(addeds, voteWeights, governors, brigdeOperators);
  }

  /**
   * @dev Internal function to remove bridge operators.
   *
   * This function removes the specified `bridgeOperators` from the bridge operator set and related mappings.
   *
   * Requirements:
   * - The caller must have the necessary permission to remove bridge operators.
   *
   * @param bridgeOperators An array of addresses representing the bridge operators to be removed.
   * @return removeds An array of boolean values indicating whether each bridge operator was successfully removed.
   */
  function _removeBridgeOperators(
    address[] memory bridgeOperators
  ) internal nonDuplicate(bridgeOperators) returns (bool[] memory removeds) {
    uint256 length = bridgeOperators.length;
    removeds = new bool[](length);

    mapping(address => address) storage _governorOf = _getGovernorOf();
    EnumerableSet.AddressSet storage _governorSet = _getGovernorsSet();
    EnumerableSet.AddressSet storage _bridgeOperatorSet = _getBridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();

    address governor;
    address bridgeOperator;
    uint256 accumulatedWeight;
    BridgeOperatorInfo memory bridgeOperatorInfo;
    for (uint256 i; i < length; ) {
      bridgeOperator = bridgeOperators[i];
      governor = _governorOf[bridgeOperator];

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeOperator);

      bridgeOperatorInfo = _governorToBridgeOperatorInfo[governor];
      if (bridgeOperatorInfo.addr != bridgeOperator) revert ErrInvalidArguments(msg.sig);

      removeds[i] = _bridgeOperatorSet.remove(bridgeOperator);
      if (removeds[i]) {
        delete _governorOf[bridgeOperator];
        _governorSet.remove(governor);
        delete _governorToBridgeOperatorInfo[governor];
        accumulatedWeight += bridgeOperatorInfo.voteWeight;
      }

      unchecked {
        ++i;
      }
    }

    _totalWeight -= accumulatedWeight;

    emit BridgeOperatorsRemoved(removeds, bridgeOperators);
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(
    uint256 numerator,
    uint256 denominator
  ) internal virtual returns (uint256 _previousNum, uint256 _previousDenom) {
    if (numerator > denominator) revert ErrInvalidThreshold(msg.sig);

    _previousNum = _num;
    _previousDenom = _denom;
    _num = numerator;
    _denom = denominator;

    unchecked {
      emit ThresholdUpdated(_nonce++, numerator, denominator, _previousNum, _previousDenom);
    }
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _totalWeight;
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _getBridgeOperatorSet() internal pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly {
      bridgeOperators.slot := BRIDGE_OPERATOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return governors_ the storage address set.
   */
  function _getGovernorsSet() internal pure returns (EnumerableSet.AddressSet storage governors_) {
    assembly {
      governors_.slot := GOVERNOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from governor => BridgeOperatorInfo.
   * @return governorToBridgeOperatorInfo_ the mapping from governor => BridgeOperatorInfo.
   */
  function _getGovernorToBridgeOperatorInfo()
    internal
    pure
    returns (mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo_)
  {
    assembly {
      governorToBridgeOperatorInfo_.slot := GOVERNOR_TO_BRIDGE_OPERATOR_INFO_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => governor.
   * @return govenorOf_ the mapping from bridge operator => governor.
   */
  function _getGovernorOf() internal pure returns (mapping(address => address) storage govenorOf_) {
    assembly {
      govenorOf_.slot := GOVENOR_OF_SLOT
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

  /**
   * @dev Internal function to perform sanity checks on vote weight, governor, and bridge operator.
   *
   * This function verifies that the `voteWeight` is non-zero and checks for duplicate addresses among `governor` and `bridgeOperator`.
   *
   * Requirements:
   * - The `voteWeight` must be non-zero.
   * - The `governor` and `bridgeOperator` addresses must not be duplicates.
   *
   * @param voteWeight The vote weight to be checked.
   * @param governor The address of the governor to be checked.
   * @param bridgeOperator The address of the bridge operator to be checked.
   */
  function _sanityCheck(uint256 voteWeight, address governor, address bridgeOperator) private pure {
    if (voteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);

    address[] memory addrs = new address[](2);
    addrs[0] = governor;
    addrs[1] = bridgeOperator;

    _checkDuplicate(addrs);
  }

  /**
   * @dev Internal method to check method caller.
   *
   * Requirements:
   *
   * - The method caller must be this contract.
   *
   */
  function _requireSelfCall() internal view virtual {
    if (msg.sender != address(this)) revert ErrOnlySelfCall(msg.sig);
  }
}
