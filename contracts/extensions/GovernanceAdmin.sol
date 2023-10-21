// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/sequential-governance/CoreGovernance.sol";
import "../extensions/collections/HasContracts.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import { ErrorHandler } from "../libraries/ErrorHandler.sol";
import { IdentityGuard } from "../utils/IdentityGuard.sol";
import { HasGovernanceAdminDeprecated, HasBridgeDeprecated } from "../utils/DeprecatedSlots.sol";

abstract contract GovernanceAdmin is
  CoreGovernance,
  IdentityGuard,
  HasContracts,
  HasGovernanceAdminDeprecated,
  HasBridgeDeprecated
{
  using ErrorHandler for bool;

  uint256 public roninChainId;
  /// @dev Domain separator
  bytes32 public DOMAIN_SEPARATOR;

  constructor(uint256 _roninChainId, address _roninTrustedOrganizationContract) {
    roninChainId = _roninChainId;

    /*
     * DOMAIN_SEPARATOR = keccak256(
     *  abi.encode(
     *    keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
     *    keccak256("GovernanceAdmin"), // name hash
     *    keccak256("2"), // version hash
     *    keccak256(abi.encode("RONIN_GOVERNANCE_ADMIN", _roninChainId)) // salt
     *  )
     */
    assembly {
      let ptr := mload(0x40)

      // See abi.encode implementation: https://github.com/axieinfinity/ronin/blob/569ebd5a782da5601c6aba22799dc9b4afd39da9/accounts/abi/argument.go#L227-L267
      mstore(ptr, 0x40) // offset bytes
      mstore(add(ptr, 0x20), _roninChainId)
      mstore(add(ptr, 0x40), 0x16) // "RONIN_GOVERNANCE_ADMIN".length
      mstore(add(ptr, 0x60), 0x524f4e494e5f474f5645524e414e43455f41444d494e00000000000000000000) // bytes("RONIN_GOVERNANCE_ADMIN")
      let salt := keccak256(ptr, 0x80) // keccak256(abi.encode("RONIN_GOVERNANCE_ADMIN", _roninChainId))

      mstore(ptr, 0x599a80fcaa47b95e2323ab4d34d34e0cc9feda4b843edafcc30c7bdf60ea15bf) // keccak256("EIP712Domain(string name,string version,bytes32 salt)")
      mstore(add(ptr, 0x20), 0x7e7935007966eb860f4a2ee3dcc9fd53fb3205ce2aa86b0126d4893d4d4c14b9) // keccak256("GovernanceAdmin")
      mstore(add(ptr, 0x40), 0x2a80e1ef1d7842f27f2e6be0972bb708b9a135c38860dbe73c27c3486c34f4de) // keccak256("3")
      mstore(add(ptr, 0x60), salt)
      sstore(DOMAIN_SEPARATOR.slot, keccak256(ptr, 0x80))
    }

    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, _roninTrustedOrganizationContract);
  }

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(ContractType contractType, address addr) external virtual override onlySelfCall {
    _requireHasCode(addr);
    _setContract(contractType, addr);
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
    (bool _success, bytes memory _returndata) = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION).staticcall(
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
  function _getTotalWeight() internal view virtual override returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.totalWeight.selector;
    (bool _success, bytes memory _returndata) = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector)
      )
    );
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }
}
