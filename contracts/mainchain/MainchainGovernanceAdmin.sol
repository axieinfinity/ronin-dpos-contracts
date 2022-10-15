// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/isolated-governance/bridge-operator-governance/BOsGovernanceRelay.sol";
import "../extensions/sequential-governance/GovernanceRelay.sol";
import "../extensions/GovernanceAdmin.sol";
import "../interfaces/IBridge.sol";

contract MainchainGovernanceAdmin is GovernanceRelay, GovernanceAdmin, BOsGovernanceRelay {
  bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

  constructor(
    address _roleSetter,
    address _roninTrustedOrganizationContract,
    address _bridgeContract,
    address[] memory _relayers
  ) GovernanceAdmin(_roleSetter, _roninTrustedOrganizationContract, _bridgeContract) {
    for (uint256 _i; _i < _relayers.length; _i++) {
      _grantRole(RELAYER_ROLE, _relayers[_i]);
    }
  }

  /**
   * @dev See {GovernanceRelay-_relayProposal}.
   *
   * Requirements:
   * - The method caller is relayer.
   *
   */
  function relayProposal(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyRole(RELAYER_ROLE) {
    _relayProposal(_proposal, _supports, _signatures, DOMAIN_SEPARATOR, msg.sender);
  }

  /**
   * @dev See {GovernanceRelay-_relayGlobalProposal}.
   *
   * Requirements:
   * - The method caller is relayer.
   *
   */
  function relayGlobalProposal(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyRole(RELAYER_ROLE) {
    _relayGlobalProposal(
      _globalProposal,
      _supports,
      _signatures,
      DOMAIN_SEPARATOR,
      roninTrustedOrganizationContract(),
      bridgeContract(),
      msg.sender
    );
  }

  /**
   * @dev See {BOsGovernanceRelay-_relayVotesBySignatures}.
   *
   * Requirements:
   * - The method caller is relayer.
   *
   */
  function relayBridgeOperators(
    uint256 _period,
    WeightedAddress[] calldata _operators,
    Signature[] calldata _signatures
  ) external onlyRole(RELAYER_ROLE) {
    _relayVotesBySignatures(_operators, _signatures, _period, _getMinimumVoteWeight(), DOMAIN_SEPARATOR);
    _bridgeContract.replaceBridgeOperators(_operators);
  }

  /**
   * @dev Override {CoreGovernance-_getWeights}.
   */
  function _getWeights(address[] memory _governors)
    internal
    view
    virtual
    override(BOsGovernanceRelay, GovernanceRelay)
    returns (uint256)
  {
    (bool _success, bytes memory _returndata) = roninTrustedOrganizationContract().staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(IRoninTrustedOrganization.sumWeights.selector, _governors)
      )
    );
    require(_success, "GovernanceAdmin: proxy call `sumWeights(address[])` failed");
    return abi.decode(_returndata, (uint256));
  }
}
