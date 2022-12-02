// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/sequential-governance/CoreGovernance.sol";
import "../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../extensions/collections/HasBridgeContract.sol";
import "../interfaces/IRoninTrustedOrganization.sol";

abstract contract GovernanceAdmin is CoreGovernance, HasRoninTrustedOrganizationContract, HasBridgeContract {
  /// @dev Domain separator
  bytes32 public constant DOMAIN_SEPARATOR = 0xf8704f8860d9e985bf6c52ec4738bd10fe31487599b36c0944f746ea09dc256b;

  modifier onlySelfCall() {
    require(msg.sender == address(this), "GovernanceAdmin: only allowed self-call");
    _;
  }

  constructor(
    address _roninTrustedOrganizationContract,
    address _bridgeContract,
    uint256 _proposalExpiryDuration
  ) CoreGovernance(_proposalExpiryDuration) {
    require(
      keccak256(
        abi.encode(
          keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
          keccak256("GovernanceAdmin"), // name hash
          keccak256("1"), // version hash
          keccak256(abi.encode("RONIN_GOVERNANCE_ADMIN", 2020)) // salt
        )
      ) == DOMAIN_SEPARATOR,
      "GovernanceAdmin: invalid domain"
    );
    _setRoninTrustedOrganizationContract(_roninTrustedOrganizationContract);
    _setBridgeContract(_bridgeContract);
  }

  /**
   * @inheritdoc IHasRoninTrustedOrganizationContract
   */
  function setRoninTrustedOrganizationContract(address _addr) external override onlySelfCall {
    require(_addr.code.length > 0, "GovernanceAdmin: set to non-contract");
    _setRoninTrustedOrganizationContract(_addr);
  }

  /**
   * @inheritdoc IHasBridgeContract
   */
  function setBridgeContract(address _addr) external override onlySelfCall {
    require(_addr.code.length > 0, "GovernanceAdmin: set to non-contract");
    _setBridgeContract(_addr);
  }

  /**
   * @dev Sets the expiry duration for a new proposal.
   *
   * Requirements:
   * - Only admin can call this method.
   *
   */
  function setProposalExpiryDuration(uint256 _expiryDuration) external onlyAdmin {
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
    (bool _success, bytes memory _returndata) = _proxy.staticcall(hex"5c60da1b");
    require(_success, "GovernanceAdmin: proxy call `implementation()` failed");
    return abi.decode(_returndata, (address));
  }

  /**
   * @dev Returns the proposal expiry duration.
   */
  function getProposalExpiryDuration() external returns (uint256) {
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
    (bool _success, bytes memory _returndata) = _proxy.staticcall(hex"f851a440");
    require(_success, "GovernanceAdmin: proxy call `admin()` failed");
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
    (bool _success, ) = _proxy.call(abi.encodeWithSelector(0x8f283970, _newAdmin));
    require(_success, "GovernanceAdmin: proxy call `changeAdmin(address)` failed");
  }

  /**
   * @dev Override `CoreGovernance-_getMinimumVoteWeight`.
   */
  function _getMinimumVoteWeight() internal view virtual override returns (uint256) {
    (bool _success, bytes memory _returndata) = roninTrustedOrganizationContract().staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(IQuorum.minimumVoteWeight.selector)
      )
    );
    require(_success, "GovernanceAdmin: proxy call `minimumVoteWeight()` failed");
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @dev Override `CoreGovernance-_getTotalWeights`.
   */
  function _getTotalWeights() internal view virtual override returns (uint256) {
    (bool _success, bytes memory _returndata) = roninTrustedOrganizationContract().staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(IRoninTrustedOrganization.totalWeights.selector)
      )
    );
    require(_success, "GovernanceAdmin: proxy call `totalWeights()` failed");
    return abi.decode(_returndata, (uint256));
  }
}
