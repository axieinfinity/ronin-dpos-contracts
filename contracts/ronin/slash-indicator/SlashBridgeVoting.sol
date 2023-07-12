// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../libraries/Math.sol";
import { HasValidatorDeprecated, HasTrustedOrgDeprecated, HasGovernanceAdminDeprecated } from "../../utils/DeprecatedSlots.sol";
import { IBridgeAdminProposal } from "../../interfaces/IBridgeAdminProposal.sol";
import "../../interfaces/slash-indicator/ISlashBridgeVoting.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../extensions/collections/HasContracts.sol";

// TODO: remove this from slashing logic of consensus contract
abstract contract SlashBridgeVoting is
  ISlashBridgeVoting,
  HasContracts,
  HasValidatorDeprecated,
  HasTrustedOrgDeprecated,
  HasGovernanceAdminDeprecated
{
  /// @dev Mapping from validator address => period index => bridge voting slashed
  mapping(address => mapping(uint256 => bool)) internal _bridgeVotingSlashed;
  /// @dev The threshold to slash when a trusted organization does not vote for bridge operators.
  uint256 internal _bridgeVotingThreshold;
  /// @dev The amount of RON to slash bridge voting.
  uint256 internal _bridgeVotingSlashAmount;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ISlashBridgeVoting
   */
  function slashBridgeVoting(address _consensusAddr) external onlyAdmin {
    IRoninTrustedOrganization.TrustedOrganization memory _org = IRoninTrustedOrganization(
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)
    ).getTrustedOrganization(_consensusAddr);
    uint256 _lastVotedBlock = Math.max(
      IBridgeAdminProposal(getContract(ContractType.BRIDGE_MANAGER)).lastVotedBlock(_org.bridgeVoter),
      _org.addedBlock
    );
    IRoninValidatorSet _validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    uint256 _period = _validatorContract.currentPeriod();

    if (block.number - _lastVotedBlock <= _bridgeVotingThreshold || _bridgeVotingSlashed[_consensusAddr][_period])
      revert ErrInvalidSlash();

    _bridgeVotingSlashed[_consensusAddr][_period] = true;
    emit Slashed(_consensusAddr, SlashType.BRIDGE_VOTING, _period);
    _validatorContract.execSlash(_consensusAddr, 0, _bridgeVotingSlashAmount, false);
  }

  /**
   * @inheritdoc ISlashBridgeVoting
   */
  function getBridgeVotingSlashingConfigs()
    external
    view
    override
    returns (uint256 bridgeVotingThreshold_, uint256 bridgeVotingSlashAmount_)
  {
    return (_bridgeVotingThreshold, _bridgeVotingSlashAmount);
  }

  /**
   * @inheritdoc ISlashBridgeVoting
   */
  function setBridgeVotingSlashingConfigs(uint256 _threshold, uint256 _slashAmount) external override onlyAdmin {
    _setBridgeVotingSlashingConfigs(_threshold, _slashAmount);
  }

  /**
   * @dev See `ISlashBridgeVoting-setBridgeVotingSlashingConfigs`.
   */
  function _setBridgeVotingSlashingConfigs(uint256 _threshold, uint256 _slashAmount) internal {
    _bridgeVotingThreshold = _threshold;
    _bridgeVotingSlashAmount = _slashAmount;
    emit BridgeVotingSlashingConfigsUpdated(_threshold, _slashAmount);
  }
}
