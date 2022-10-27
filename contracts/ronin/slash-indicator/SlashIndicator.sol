// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/ISlashIndicator.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "./SlashDoubleSign.sol";
import "./SlashBridgeVoting.sol";
import "./SlashBridgeOperator.sol";
import "./SlashUnavailability.sol";

contract SlashIndicator is
  ISlashIndicator,
  SlashDoubleSign,
  SlashBridgeVoting,
  SlashBridgeOperator,
  SlashUnavailability,
  HasMaintenanceContract,
  Initializable
{
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    address __maintenanceContract,
    address __roninTrustedOrganizationContract,
    address __roninGovernanceAdminContract,
    // _bridgeOperatorConfigs[0]: _missingVotesRatioTier1
    // _bridgeOperatorConfigs[1]: _missingVotesRatioTier2
    // _bridgeOperatorConfigs[2]: _jailDurationForMissingVotesRatioTier2
    uint256[3] calldata _bridgeOperatorConfigs,
    // _bridgeVotingConfigs[0]: _bridgeVotingThreshold
    // _bridgeVotingConfigs[1]: _bridgeVotingSlashAmount
    uint256[2] calldata _bridgeVotingConfigs,
    // _doubleSignConfigs[0]: _doubleSigningConstrainBlocks
    // _doubleSignConfigs[1]: _slashDoubleSignAmount
    // _doubleSignConfigs[2]: _doubleSigningJailUntilBlock
    uint256[3] calldata _doubleSignConfigs,
    // _unavailabilitySlashConfigs[0]: _unavailabilityTier1Threshold
    // _unavailabilitySlashConfigs[1]: _unavailabilityTier2Threshold
    // _unavailabilitySlashConfigs[2]: _slashAmountForUnavailabilityTier2Threshold
    // _unavailabilitySlashConfigs[3]: _jailDurationForUnavailabilityTier2Threshold
    uint256[4] calldata _unavailabilitySlashConfigs
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMaintenanceContract(__maintenanceContract);
    _setRoninTrustedOrganizationContract(__roninTrustedOrganizationContract);
    _setRoninGovernanceAdminContract(__roninGovernanceAdminContract);
    _setBridgeOperatorSlashConfigs(_bridgeOperatorConfigs[0], _bridgeOperatorConfigs[1], _bridgeOperatorConfigs[2]);
    _setBridgeVotingSlashConfigs(_bridgeVotingConfigs[0], _bridgeVotingConfigs[1]);
    _setDoubleSignSlashConfigs(_doubleSignConfigs[0], _doubleSignConfigs[1], _doubleSignConfigs[2]);
    _setUnavailabilitySlashConfigs(
      _unavailabilitySlashConfigs[0],
      _unavailabilitySlashConfigs[1],
      _unavailabilitySlashConfigs[2],
      _unavailabilitySlashConfigs[3]
    );
  }

  /**
   * @dev Sanity check the address to be slashed
   */
  function _shouldSlash(address _addr) internal view override(SlashDoubleSign, SlashUnavailability) returns (bool) {
    return
      (msg.sender != _addr) &&
      _validatorContract.isBlockProducer(_addr) &&
      !_maintenanceContract.maintaining(_addr, block.number);
  }
}
