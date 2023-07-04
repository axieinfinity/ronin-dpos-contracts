// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IBridgeAdminOperator } from "../../interfaces/IBridgeAdminOperator.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { ErrInvalidThreshold, ErrInvalidVoteWeight, ErrEmptyArray, ErrZeroAddress, ErrUnauthorized } from "../../utils/CommonErrors.sol";

abstract contract BridgeAdminOperator is IQuorum, IBridgeAdminOperator, HasContracts {
  using SafeCast for uint256;
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

  bytes32 public DOMAIN_SEPARATOR;

  uint256 internal _num;
  uint256 internal _denom;
  uint256 internal _nonce;
  uint256 internal _totalWeight;

  modifier nonDuplicate(address[] memory arr) {
    _checkDuplicate(arr);
    _;
  }

  constructor(uint256 num, uint256 denom, uint256 roninChainId, address admin, address bridgeContract) payable {
    _checkNonZeroAddress(admin);
    assembly {
      sstore(_ADMIN_SLOT, admin)
    }
    _setContract(ContractType.BRIDGE, bridgeContract);

    _nonce = 1;
    _num = num;
    _denom = denom;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("1"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", roninChainId)) // salt
      )
    );
  }

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
  ) external onlyContract(ContractType.BRIDGE) returns (bool[] memory removeds) {
    return _removeBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
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

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Update);
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) external override onlyAdmin returns (uint256, uint256) {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getTotalWeights() external view returns (uint256) {
    return _totalWeight;
  }

  function getBridgeVoterWeight(address governor) external view returns (uint256) {
    return _getGovernorToBridgeOperatorInfo()[governor].voteWeight;
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeVoterWeights(address[] calldata governors) external view returns (uint256[] memory weights) {
    uint256 length = governors.length;
    weights = new uint256[](length);
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
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
    uint256 length = _getBridgeOperatorSet().length();
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();
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
    return _getBridgeOperatorSet().length();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    return _getBridgeOperatorSet().contains(addr);
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeOperators() public view returns (address[] memory) {
    return _getBridgeOperatorSet().values();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getGovernors() external view returns (address[] memory) {
    return _getGovernorsSet().values();
  }

  /**
   * @inheritdoc IBridgeAdminOperator
   */
  function getBridgeOperatorOf(address[] calldata governors) external view returns (address[] memory bridgeOperators_) {
    uint256 length = governors.length;
    bridgeOperators_ = new address[](length);

    mapping(address => BridgeOperatorInfo) storage gorvernorToBridgeOperator = _getGovernorToBridgeOperatorInfo();
    for (uint256 i; i < length; ) {
      bridgeOperators_[i] = gorvernorToBridgeOperator[governors[i]].addr;
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

  function _addBridgeOperators(
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory brigdeOperators
  ) internal returns (bool[] memory addeds) {
    uint256 length = brigdeOperators.length;
    addeds = new bool[](length);

    EnumerableSet.AddressSet storage governorSet = _getGovernorsSet();
    mapping(address => address) storage _governorOf = _getGovernorOf();
    EnumerableSet.AddressSet storage bridgeOperatorSet = _getBridgeOperatorSet();
    mapping(address => BridgeOperatorInfo) storage governorToBridgeOperatorInfo = _getGovernorToBridgeOperatorInfo();

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

      if (addeds[i]) {
        governorSet.add(governor);

        accumulateWeight += voteWeight;

        _governorOf[bridgeOperator] = governor;

        bridgeOperatorInfo.addr = bridgeOperator;
        bridgeOperatorInfo.voteWeight = voteWeight;
        governorToBridgeOperatorInfo[governor] = bridgeOperatorInfo;
      }

      unchecked {
        ++i;
      }
    }

    _totalWeight += accumulateWeight;

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Add);
  }

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
    uint256 accumulateWeight;
    BridgeOperatorInfo memory bridgeOperatorInfo;
    for (uint256 i; i < length; ) {
      bridgeOperator = bridgeOperators[i];
      governor = _governorOf[bridgeOperator];

      _checkNonZeroAddress(governor);
      _checkNonZeroAddress(bridgeOperator);

      bridgeOperatorInfo = _governorToBridgeOperatorInfo[governor];
      assert(bridgeOperatorInfo.addr == bridgeOperator);

      removeds[i] = _bridgeOperatorSet.remove(bridgeOperator);
      if (removeds[i]) {
        delete _governorOf[bridgeOperator];
        _governorSet.remove(governor);
        delete _governorToBridgeOperatorInfo[governor];
        accumulateWeight += bridgeOperatorInfo.voteWeight;
      }

      unchecked {
        ++i;
      }
    }

    _totalWeight -= accumulateWeight;

    emit BridgeOperatorSetModified(msg.sender, BridgeAction.Remove);
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) internal virtual returns (uint256 _previousNum, uint256 _previousDenom) {
    if (_numerator > _denominator) revert ErrInvalidThreshold(msg.sig);

    _previousNum = _num;
    _previousDenom = _denom;
    _num = _numerator;
    _denom = _denominator;

    unchecked {
      emit ThresholdUpdated(_nonce++, _numerator, _denominator, _previousNum, _previousDenom);
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

  function _sanityCheck(uint256 voteWeight, address governor, address bridgeOperator) private pure {
    if (voteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);

    address[] memory addrs = new address[](2);
    addrs[0] = governor;
    addrs[1] = bridgeOperator;

    _checkDuplicate(addrs);
  }
}
