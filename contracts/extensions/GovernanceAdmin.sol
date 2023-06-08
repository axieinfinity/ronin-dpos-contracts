// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/sequential-governance/CoreGovernance.sol";
import "../extensions/collections/HasContracts.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import "../libraries/ErrorHandler.sol";
import { HasGovernanceAdminDeprecated, HasBridgeDeprecated } from "../libraries/DeprecatedSlots.sol";

abstract contract GovernanceAdmin is CoreGovernance, HasContracts, HasGovernanceAdminDeprecated, HasBridgeDeprecated {
  using ErrorHandler for bool;

  uint256 public roninChainId;
  /// @dev Domain separator
  bytes32 public DOMAIN_SEPARATOR;

  modifier onlySelfCall() {
    _requireSelfCall();
    _;
  }

  constructor(
    uint256 _roninChainId,
    address _roninTrustedOrganizationContract,
    address _bridgeContract,
    uint256 _proposalExpiryDuration
  ) CoreGovernance(_proposalExpiryDuration) {
    assembly {
      /// roninChainId = _roninChainId
      sstore(roninChainId.slot, _roninChainId)
      let freeMemPtr := mload(0x40)
      /// @dev value is equal abi.encode("RONIN_GOVERNANCE_ADMIN", _roninChainId).length
      mstore(freeMemPtr, 0x40)
      mstore(add(freeMemPtr, 0x20), _roninChainId)
      /// @dev value is equal "RONIN_GOVERNANCE_ADMIN".length
      mstore(add(freeMemPtr, 0x40), 0x16)
      /// @dev value is equal bytes("RONIN_GOVERNANCE_ADMIN")
      mstore(add(freeMemPtr, 0x60), 0x524f4e494e5f474f5645524e414e43455f41444d494e00000000000000000000)
      let salt := keccak256(freeMemPtr, 0x80)
      /// @dev value is equal keccak256("EIP712Domain(string name,string version,bytes32 salt)")
      mstore(freeMemPtr, 0x599a80fcaa47b95e2323ab4d34d34e0cc9feda4b843edafcc30c7bdf60ea15bf)
      /// @dev value is equal keccak256("GovernanceAdmin")
      mstore(add(freeMemPtr, 0x20), 0x7e7935007966eb860f4a2ee3dcc9fd53fb3205ce2aa86b0126d4893d4d4c14b9)
      /// @dev value is equal keccak256("2")
      mstore(add(freeMemPtr, 0x40), 0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68eb14a5)
      mstore(add(freeMemPtr, 0x60), salt)
      sstore(DOMAIN_SEPARATOR.slot, keccak256(freeMemPtr, 0x80))
    }

    _setContract(Role.BRIDGE_CONTRACT, _bridgeContract);
    _setContract(Role.RONIN_TRUSTED_ORGANIZATION_CONTRACT, _roninTrustedOrganizationContract);
  }

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(Role role, address addr) external virtual override onlySelfCall {
    _requireHasCode(addr);
    _setContract(role, addr);
  }

  /**
   * @dev Sets the expiry duration for a new proposal.
   *
   * Requirements:
   * - Only allowing self-call to this method, since this contract does not have admin.
   *
   */
  function setProposalExpiryDuration(uint256 _expiryDuration) external onlySelfCall {
    _setProposalExpiryDuration(_expiryDuration);
  }

  /**
   * @dev Returns the current implementation of `_proxy`.
   *
   * Requirements:
   * - This contract must be the admin of `_proxy`.
   *
   */
  function getProxyImplementation(address _proxy) external view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("implementation()")) == 0x5c60da1b
    bytes4 _selector = 0x5c60da1b;
    (bool _success, bytes memory _returndata) = _proxy.staticcall(abi.encodeWithSelector(_selector));
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (address));
  }

  /**
   * @dev Returns the proposal expiry duration.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return super._getProposalExpiryDuration();
  }

  /**
   * @dev Returns the current admin of `_proxy`.
   *
   * Requirements:
   * - This contract must be the admin of `_proxy`.
   *
   */
  function getProxyAdmin(address _proxy) external view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("admin()")) == 0xf851a440
    bytes4 _selector = 0xf851a440;
    (bool _success, bytes memory _returndata) = _proxy.staticcall(abi.encodeWithSelector(_selector));
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (address));
  }

  /**
   * @dev Changes the admin of `_proxy` to `newAdmin`.
   *
   * Requirements:
   * - This contract must be the current admin of `_proxy`.
   *
   */
  function changeProxyAdmin(address _proxy, address _newAdmin) external onlySelfCall {
    // bytes4(keccak256("changeAdmin(address)"))
    bytes4 _selector = 0x8f283970;
    (bool _success, bytes memory _returndata) = _proxy.call(abi.encodeWithSelector(_selector, _newAdmin));
    _success.handleRevert(_selector, _returndata);
  }

  /**
   * @dev Override `CoreGovernance-_getMinimumVoteWeight`.
   */
  function _getMinimumVoteWeight() internal view virtual override returns (uint256) {
    bytes4 _selector = IQuorum.minimumVoteWeight.selector;
    (bool _success, bytes memory _returndata) = getContract(Role.RONIN_TRUSTED_ORGANIZATION_CONTRACT).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector)
      )
    );
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @dev Override `CoreGovernance-_getTotalWeights`.
   */
  function _getTotalWeights() internal view virtual override returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.totalWeights.selector;
    (bool _success, bytes memory _returndata) = getContract(Role.RONIN_TRUSTED_ORGANIZATION_CONTRACT).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector)
      )
    );
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }

  function _requireSelfCall() internal view virtual {
    if (msg.sender != address(this)) revert ErrOnlySelfCall(msg.sig);
  }
}
