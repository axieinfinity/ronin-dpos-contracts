// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../libraries/Math.sol";
import "../../interfaces/ISlashBridgeVoting.sol";
import "../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../extensions/collections/HasRoninGovernanceAdminContract.sol";
import "../../extensions/collections/HasValidatorContract.sol";

contract SlashBridgeVoting is
  ISlashBridgeVoting,
  HasValidatorContract,
  HasRoninTrustedOrganizationContract,
  HasRoninGovernanceAdminContract
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
  function slashBridgeVoting(address _consensusAddr) external {
    IRoninTrustedOrganization.TrustedOrganization memory _org = _roninTrustedOrganizationContract
      .getTrustedOrganization(_consensusAddr);
    uint256 _lastVotedBlock = Math.max(_roninGovernanceAdminContract.lastVotedBlock(_org.bridgeVoter), _org.addedBlock);
    uint256 _period = _validatorContract.currentPeriod();
    if (block.number - _lastVotedBlock > _bridgeVotingThreshold && !_bridgeVotingSlashed[_consensusAddr][_period]) {
      _bridgeVotingSlashed[_consensusAddr][_period] = true;
      emit Slashed(_consensusAddr, SlashType.BRIDGE_VOTING, _period);
      _validatorContract.slash(_consensusAddr, 0, _bridgeVotingSlashAmount);
    }
  }

  /**
   * @inheritdoc ISlashBridgeVoting
   */
  function getBridgeVotingSlashingConfigs() external view override returns (uint256, uint256) {
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
    _slashAmount = _bridgeVotingSlashAmount;
    emit BridgeVotingSlashingConfigsUpdated(_threshold, _slashAmount);
  }
}
