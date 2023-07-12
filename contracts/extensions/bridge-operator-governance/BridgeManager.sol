// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IBridgeManagerCallback, EnumerableSet, BridgeManagerCallback } from "./BridgeManagerCallback.sol";
import { IHasContracts, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { RONTransferHelper } from "../../extensions/RONTransferHelper.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { TUint256 } from "../../types/Types.sol";
import "../../utils/CommonErrors.sol";

abstract contract BridgeManager is IQuorum, IBridgeManager, BridgeManagerCallback, HasContracts {
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
   * @dev The numerator value used for calculations in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.numerator.slot") - 1
   */
  TUint256 internal constant NUMERATOR_SLOT =
    TUint256.wrap(0xc55405a488814eaa0e2a685a0131142785b8d033d311c8c8244e34a7c12ca40f);

  /**
   * @dev The denominator value used for calculations in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.denominator.slot") - 1
   */
  TUint256 internal constant DENOMINATOR_SLOT =
    TUint256.wrap(0xac1ff16a4f04f2a37a9ba5252a69baa100b460e517d1f8019c054a5ad698f9ff);

  /**
   * @dev The nonce value used for tracking nonces in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.nonce.slot") - 1
   */
  TUint256 internal constant NONCE_SLOT =
    TUint256.wrap(0x92872d32822c9d44b36a2537d3e0d4c46fc4de1ce154ccfaed560a8a58445f1d);

  /**
   * @dev The total weight value used for storing the cumulative weight in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.totalWeights.slot") - 1
   */
  TUint256 internal constant TOTAL_WEIGHTS_SLOT =
    TUint256.wrap(0x6924fe71b0c8b61aea02ca498b5f53b29bd95726278b1fe4eb791bb24a42644c);

  /**
   * @dev The domain separator used for computing hash digests in the contract.
   */
  bytes32 public immutable DOMAIN_SEPARATOR;

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
    address bridgeContract,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  ) payable {
    NONCE_SLOT.store(1);
    NUMERATOR_SLOT.store(num);
    DENOMINATOR_SLOT.store(denom);

    _setContract(ContractType.BRIDGE, bridgeContract);

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
   * @inheritdoc IBridgeManager
   */
  function addBridgeOperators(
    uint256[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  ) external onlySelfCall returns (bool[] memory addeds) {
    addeds = _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function removeBridgeOperators(
    address[] calldata bridgeOperators
  ) external onlySelfCall returns (bool[] memory removeds) {
    return _removeBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function updateBridgeOperator(address newBridgeOperator) external returns (bool updated) {
    _requireNonZeroAddress(newBridgeOperator);

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

    _notifyRegisters(
      IBridgeManagerCallback.onBridgeOperatorUpdated.selector,
      abi.encode(currentBridgeOperator, newBridgeOperator, updated)
    );

    emit BridgeOperatorUpdated(msg.sender, currentBridgeOperator, newBridgeOperator);
  }

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(ContractType contractType, address addr) external override onlySelfCall {
    _requireHasCode(addr);
    _setContract(contractType, addr);
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(
    uint256 numerator,
    uint256 denominator
  ) external override onlySelfCall returns (uint256, uint256) {
    return _setThreshold(numerator, denominator);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getTotalWeights() public view returns (uint256) {
    return TOTAL_WEIGHTS_SLOT.load();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeVoterWeight(address governor) external view returns (uint256) {
    return _getGovernorToBridgeOperatorInfo()[governor].voteWeight;
  }

  /**
   * @inheritdoc IBridgeManager
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
   * @inheritdoc IBridgeManager
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
   * @inheritdoc IBridgeManager
   */
  function totalBridgeOperators() external view returns (uint256) {
    return _getBridgeOperatorSet().length();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _getBridgeOperatorSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeOperators() public view returns (address[] memory) {
    return _getBridgeOperatorSet().values();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernors() external view returns (address[] memory) {
    return _getGovernorsSet().values();
  }

  /**
   * @inheritdoc IBridgeManager
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
    return (NUMERATOR_SLOT.mul(TOTAL_WEIGHTS_SLOT.load()) + DENOMINATOR_SLOT.load() - 1) / DENOMINATOR_SLOT.load();
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
    address[] memory bridgeOperators
  ) internal nonDuplicate(governors.extend(bridgeOperators)) returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
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
      address bridgeOperator;
      BridgeOperatorInfo memory bridgeOperatorInfo;

      for (uint256 i; i < length; ) {
        governor = governors[i];
        bridgeOperator = bridgeOperators[i];

        _requireNonZeroAddress(governor);
        _requireNonZeroAddress(bridgeOperator);
        _requirePayableAddress(bridgeOperator);

        addeds[i] = bridgeOperatorSet.add(bridgeOperator);

        if (addeds[i]) {
          _governorSet.add(governor);

          if (voteWeights[i].toUint96() == 0) revert ErrInvalidVoteWeight(msg.sig);

          // get rid of stack too deep
          // bridgeOperatorInfo.voteWeight = voteWeights[i].toUint96();
          // accumulatedWeight += bridgeOperatorInfo.voteWeight
          accumulatedWeight += bridgeOperatorInfo.voteWeight = voteWeights[i].toUint96();
          _governorOf[bridgeOperator] = governor;
          bridgeOperatorInfo.addr = bridgeOperator;
          _governorToBridgeOperatorInfo[governor] = bridgeOperatorInfo;
        }

        unchecked {
          ++i;
        }
      }
    }

    TOTAL_WEIGHTS_SLOT.addAssign(accumulatedWeight);

    _notifyRegisters(IBridgeManagerCallback.onBridgeOperatorsAdded.selector, abi.encode(bridgeOperators, addeds));

    emit BridgeOperatorsAdded(addeds, voteWeights, governors, bridgeOperators);
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

      _requireNonZeroAddress(governor);
      _requireNonZeroAddress(bridgeOperator);

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

    TOTAL_WEIGHTS_SLOT.subAssign(accumulatedWeight);

    _notifyRegisters(IBridgeManagerCallback.onBridgeOperatorsRemoved.selector, abi.encode(bridgeOperators, removeds));

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

    _previousNum = NUMERATOR_SLOT.load();
    _previousDenom = DENOMINATOR_SLOT.load();
    NUMERATOR_SLOT.store(numerator);
    DENOMINATOR_SLOT.store(denominator);

    unchecked {
      emit ThresholdUpdated(NONCE_SLOT.postIncrement(), numerator, denominator, _previousNum, _previousDenom);
    }
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (NUMERATOR_SLOT.load(), DENOMINATOR_SLOT.load());
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * DENOMINATOR_SLOT.load() >= NUMERATOR_SLOT.mul(TOTAL_WEIGHTS_SLOT.load());
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
    if (arr.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }
}
