// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../extensions/sequential-governance/GovernanceRelay.sol";
import "../extensions/GovernanceAdmin.sol";
import { ErrorHandler } from "../libraries/ErrorHandler.sol";

contract MainchainGovernanceAdmin is AccessControlEnumerable, GovernanceRelay, GovernanceAdmin {
  using ErrorHandler for bool;

  bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
  uint256 private constant DEFAULT_EXPIRY_DURATION = 1 << 255;

  constructor(
    uint256 _roninChainId,
    address _roleSetter,
    address _roninTrustedOrganizationContract,
    address[] memory _relayers
  ) GovernanceAdmin(_roninChainId, _roninTrustedOrganizationContract, DEFAULT_EXPIRY_DURATION) {
    _setupRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    for (uint256 _i; _i < _relayers.length; ) {
      _grantRole(RELAYER_ROLE, _relayers[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for the proposal.
   */
  function proposalRelayed(uint256 _chainId, uint256 _round) external view returns (bool) {
    return vote[_chainId][_round].status != VoteStatus.Pending;
  }

  /**
   * @dev See `GovernanceRelay-_relayProposal`.
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
   * @dev See `GovernanceRelay-_relayGlobalProposal`.
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
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION),
      getContract(ContractType.BRIDGE),
      msg.sender
    );
  }

  /**
   * @inheritdoc GovernanceRelay
   */
  function _sumWeights(address[] memory _governors) internal view virtual override returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.sumGovernorWeights.selector;
    (bool _success, bytes memory _returndata) = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector, _governors)
      )
    );
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @dev See {CoreGovernance-_getChainType}
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.Mainchain;
  }
}
