// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeManagerCallback, EnumerableSet, BridgeManagerCallbackRegister } from "./BridgeManagerCallbackRegister.sol";
import { IHasContracts, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { TUint256Slot } from "../../types/Types.sol";
import "../../utils/CommonErrors.sol";

abstract contract BridgeManager is IQuorum, IBridgeManager, BridgeManagerCallbackRegister, HasContracts {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.governorToBridgeOperatorInfo.slot") - 1
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
  TUint256Slot internal constant NUMERATOR_SLOT =
    TUint256Slot.wrap(0xc55405a488814eaa0e2a685a0131142785b8d033d311c8c8244e34a7c12ca40f);

  /**
   * @dev The denominator value used for calculations in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.denominator.slot") - 1
   */
  TUint256Slot internal constant DENOMINATOR_SLOT =
    TUint256Slot.wrap(0xac1ff16a4f04f2a37a9ba5252a69baa100b460e517d1f8019c054a5ad698f9ff);

  /**
   * @dev The nonce value used for tracking nonces in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.nonce.slot") - 1
   */
  TUint256Slot internal constant NONCE_SLOT =
    TUint256Slot.wrap(0x92872d32822c9d44b36a2537d3e0d4c46fc4de1ce154ccfaed560a8a58445f1d);

  /**
   * @dev The total weight value used for storing the cumulative weight in the contract.
   * @notice value is equal to keccak256("@ronin.dpos.gateway.BridgeAdmin.totalWeights.slot") - 1
   */
  TUint256Slot internal constant TOTAL_WEIGHTS_SLOT =
    TUint256Slot.wrap(0x6924fe71b0c8b61aea02ca498b5f53b29bd95726278b1fe4eb791bb24a42644c);

  /**
   * @inheritdoc IBridgeManager
   */
  bytes32 public immutable DOMAIN_SEPARATOR;

  modifier onlyGovernor() virtual {
    _requireGovernor(msg.sender);
    _;
  }

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights
  ) payable BridgeManagerCallbackRegister(callbackRegisters) {
    NONCE_SLOT.store(1);

    _setThreshold(num, denom);
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
    uint96[] calldata voteWeights,
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
    removeds = _removeBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeManager
   * @notice This method checks authorization by querying the corresponding operator of the msg.sender and then
   * attempts to remove it from the `_bridgeOperatorSet` for gas optimization. In case we allow a governor can leave
   * their operator address blank null `address(0)`, consider add authorization check.
   */
  function updateBridgeOperator(address newBridgeOperator) external onlyGovernor {
    _requireNonZeroAddress(newBridgeOperator);

    // Queries the previous bridge operator
    mapping(address => BridgeOperatorInfo) storage _gorvernorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    address currentBridgeOperator = _gorvernorToBridgeOperatorInfo[msg.sender].addr;
    if (currentBridgeOperator == newBridgeOperator) {
      revert ErrBridgeOperatorAlreadyExisted(newBridgeOperator);
    }

    // Tries replace the bridge operator
    EnumerableSet.AddressSet storage _bridgeOperatorSet = _getBridgeOperatorSet();
    bool updated = _bridgeOperatorSet.remove(currentBridgeOperator) && _bridgeOperatorSet.add(newBridgeOperator);
    if (!updated) revert ErrBridgeOperatorUpdateFailed(newBridgeOperator);

    mapping(address => address) storage _governorOf = _getGovernorOf();
    delete _governorOf[currentBridgeOperator];
    _governorOf[newBridgeOperator] = msg.sender;
    _gorvernorToBridgeOperatorInfo[msg.sender].addr = newBridgeOperator;

    _notifyRegisters(
      IBridgeManagerCallback.onBridgeOperatorUpdated.selector,
      abi.encode(currentBridgeOperator, newBridgeOperator)
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
  function getTotalWeight() public view returns (uint256) {
    return TOTAL_WEIGHTS_SLOT.load();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorWeights(address[] calldata governors) external view returns (uint96[] memory weights) {
    weights = _getGovernorWeights(governors);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorWeight(address governor) external view returns (uint96 weight) {
    weight = _getGovernorWeight(governor);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function sumGovernorsWeight(
    address[] calldata governors
  ) external view nonDuplicate(governors) returns (uint256 sum) {
    sum = _sumGovernorsWeight(governors);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function totalBridgeOperator() external view returns (uint256) {
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
  function getBridgeOperators() external view returns (address[] memory) {
    return _getBridgeOperators();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernors() external view returns (address[] memory) {
    return _getGovernors();
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeOperatorOf(address[] memory governors) public view returns (address[] memory bridgeOperators) {
    uint256 length = governors.length;
    bridgeOperators = new address[](length);

    mapping(address => BridgeOperatorInfo) storage _gorvernorToBridgeOperator = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      bridgeOperators[i] = _gorvernorToBridgeOperator[governors[i]].addr;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorsOf(address[] calldata bridgeOperators) external view returns (address[] memory governors) {
    uint256 length = bridgeOperators.length;
    governors = new address[](length);
    mapping(address => address) storage _governorOf = _getGovernorOf();

    for (uint256 i; i < length; ) {
      governors[i] = _governorOf[bridgeOperators[i]];
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getFullBridgeOperatorInfos()
    external
    view
    returns (address[] memory governors, address[] memory bridgeOperators, uint96[] memory weights)
  {
    governors = _getGovernors();
    bridgeOperators = getBridgeOperatorOf(governors);
    weights = _getGovernorWeights(governors);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeOperatorWeight(address bridgeOperator) external view returns (uint96 weight) {
    mapping(address => address) storage _governorOf = _getGovernorOf();
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    weight = _governorToBridgeOperatorInfo[_governorOf[bridgeOperator]].voteWeight;
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    return (NUMERATOR_SLOT.mul(TOTAL_WEIGHTS_SLOT.load()) + DENOMINATOR_SLOT.load() - 1) / DENOMINATOR_SLOT.load();
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
    uint96[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal nonDuplicate(governors.extend(bridgeOperators)) returns (bool[] memory addeds) {
    uint256 length = bridgeOperators.length;
    if (!(length == voteWeights.length && length == governors.length)) revert ErrLengthMismatch(msg.sig);
    addeds = new bool[](length);
    // simply skip add operations if inputs are empty.
    if (length == 0) return addeds;

    EnumerableSet.AddressSet storage _governorSet = _getGovernorsSet();
    mapping(address => address) storage _governorOf = _getGovernorOf();
    EnumerableSet.AddressSet storage _bridgeOperatorSet = _getBridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();

    address governor;
    address bridgeOperator;
    uint256 accumulatedWeight;
    BridgeOperatorInfo memory bridgeOperatorInfo;

    for (uint256 i; i < length; ) {
      governor = governors[i];
      bridgeOperator = bridgeOperators[i];

      _requireNonZeroAddress(governor);
      _requireNonZeroAddress(bridgeOperator);
      if (voteWeights[i] == 0) revert ErrInvalidVoteWeight(msg.sig);

      addeds[i] = !(_governorSet.contains(governor) ||
        _governorSet.contains(bridgeOperator) ||
        _bridgeOperatorSet.contains(governor) ||
        _bridgeOperatorSet.contains(bridgeOperator));

      if (addeds[i]) {
        _governorSet.add(governor);
        _bridgeOperatorSet.add(bridgeOperator);
        _governorOf[bridgeOperator] = governor;
        bridgeOperatorInfo.addr = bridgeOperator;
        accumulatedWeight += bridgeOperatorInfo.voteWeight = voteWeights[i];
        _governorToBridgeOperatorInfo[governor] = bridgeOperatorInfo;
      }

      unchecked {
        ++i;
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
    // simply skip remove operations if inputs are empty.
    if (length == 0) return removeds;

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

      removeds[i] = _bridgeOperatorSet.contains(bridgeOperator) && _governorSet.contains(governor);
      if (removeds[i]) {
        _governorSet.remove(governor);
        _bridgeOperatorSet.remove(bridgeOperator);

        delete _governorOf[bridgeOperator];
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
  ) internal virtual returns (uint256 previousNum, uint256 previousDenom) {
    if (numerator > denominator) revert ErrInvalidThreshold(msg.sig);

    previousNum = NUMERATOR_SLOT.load();
    previousDenom = DENOMINATOR_SLOT.load();
    NUMERATOR_SLOT.store(numerator);
    DENOMINATOR_SLOT.store(denominator);

    emit ThresholdUpdated(NONCE_SLOT.postIncrement(), numerator, denominator, previousNum, previousDenom);
  }

  /**
   * @dev Internal function to get all bridge operators.
   * @return bridgeOperators An array containing all the registered bridge operator addresses.
   */
  function _getBridgeOperators() internal view returns (address[] memory) {
    return _getBridgeOperatorSet().values();
  }

  /**
   * @dev Internal function to get all governors.
   * @return governors An array containing all the registered governor addresses.
   */
  function _getGovernors() internal view returns (address[] memory) {
    return _getGovernorsSet().values();
  }

  /**
   * @dev Internal function to get the vote weights of a given array of governors.
   * @param governors An array containing the addresses of governors.
   * @return weights An array containing the vote weights of the corresponding governors.
   */
  function _getGovernorWeights(address[] memory governors) internal view returns (uint96[] memory weights) {
    uint256 length = governors.length;
    weights = new uint96[](length);
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      weights[i] = _governorToBridgeOperatorInfo[governors[i]].voteWeight;
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to calculate the sum of vote weights for a given array of governors.
   * @param governors An array containing the addresses of governors to calculate the sum of vote weights.
   * @return sum The total sum of vote weights for the provided governors.
   * @notice The input array `governors` must contain unique addresses to avoid duplicate calculations.
   */
  function _sumGovernorsWeight(address[] memory governors) internal view nonDuplicate(governors) returns (uint256 sum) {
    mapping(address => BridgeOperatorInfo) storage _governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();

    for (uint256 i; i < governors.length; ) {
      sum += _governorToBridgeOperatorInfo[governors[i]].voteWeight;

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to require that the caller has governor role access.
   * @param addr The address to check for governor role access.
   * @dev If the address does not have governor role access (vote weight is zero), a revert with the corresponding error message is triggered.
   */
  function _requireGovernor(address addr) internal view {
    if (_getGovernorWeight(addr) == 0) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }
  }

  /**
   * @dev Internal function to retrieve the vote weight of a specific governor.
   * @param governor The address of the governor to get the vote weight for.
   * @return voteWeight The vote weight of the specified governor.
   */
  function _getGovernorWeight(address governor) internal view returns (uint96) {
    return _getGovernorToBridgeOperatorInfo()[governor].voteWeight;
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return bridgeOperators the storage address set.
   */
  function _getBridgeOperatorSet() internal pure returns (EnumerableSet.AddressSet storage bridgeOperators) {
    assembly ("memory-safe") {
      bridgeOperators.slot := BRIDGE_OPERATOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the address set of bridge operators.
   * @return governors the storage address set.
   */
  function _getGovernorsSet() internal pure returns (EnumerableSet.AddressSet storage governors) {
    assembly ("memory-safe") {
      governors.slot := GOVERNOR_SET_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from governor => BridgeOperatorInfo.
   * @return governorToBridgeOperatorInfo the mapping from governor => BridgeOperatorInfo.
   */
  function _getGovernorToBridgeOperatorInfo()
    internal
    pure
    returns (mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo)
  {
    assembly ("memory-safe") {
      governorToBridgeOperatorInfo.slot := GOVERNOR_TO_BRIDGE_OPERATOR_INFO_SLOT
    }
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => governor.
   * @return governorOf the mapping from bridge operator => governor.
   */
  function _getGovernorOf() internal pure returns (mapping(address => address) storage governorOf) {
    assembly ("memory-safe") {
      governorOf.slot := GOVENOR_OF_SLOT
    }
  }
}
