// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "./CoinbaseExecution.sol";
import "./SlashingExecution.sol";

contract RoninValidatorSet is Initializable, CoinbaseExecution, SlashingExecution {
  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __slashIndicatorContract,
    address __stakingContract,
    address __stakingVestingContract,
    address __maintenanceContract,
    address __roninTrustedOrganizationContract,
    address __bridgeTrackingContract,
    uint256 __maxValidatorNumber,
    uint256 __maxValidatorCandidate,
    uint256 __maxPrioritizedValidatorNumber,
    uint256 __minEffectiveDaysOnwards,
    uint256 __numberOfBlocksInEpoch,
    // __emergencyExitConfigs[0]: emergencyExitLockedAmount
    // __emergencyExitConfigs[1]: emergencyExpiryDuration
    uint256[2] calldata __emergencyExitConfigs
  ) external initializer {
    _setContract(Role.SLASH_INDICATOR_CONTRACT, __slashIndicatorContract);
    _setContract(Role.STAKING_CONTRACT, __stakingContract);
    _setContract(Role.STAKING_VESTING_CONTRACT, __stakingVestingContract);
    _setContract(Role.MAINTENANCE_CONTRACT, __maintenanceContract);
    _setContract(Role.BRIDGE_TRACKING_CONTRACT, __bridgeTrackingContract);
    _setContract(Role.RONIN_TRUSTED_ORGANIZATION_CONTRACT, __roninTrustedOrganizationContract);

    _setMaxValidatorNumber(__maxValidatorNumber);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setMaxPrioritizedValidatorNumber(__maxPrioritizedValidatorNumber);
    _setMinEffectiveDaysOnwards(__minEffectiveDaysOnwards);
    _setEmergencyExitLockedAmount(__emergencyExitConfigs[0]);
    _setEmergencyExpiryDuration(__emergencyExitConfigs[1]);
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  /**
   * @dev Only receives RON from staking vesting contract (for topping up bonus), and from staking contract (for transferring
   * deducting amount on slashing).
   */
  function _fallback() internal view {
    if (msg.sender != getContract(Role.STAKING_VESTING_CONTRACT) && msg.sender != getContract(Role.STAKING_CONTRACT))
      revert ErrUnauthorizedReceiveRON();
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr)
    internal
    view
    override(EmergencyExit, ValidatorInfoStorage)
    returns (address)
  {
    return super._bridgeOperatorOf(_consensusAddr);
  }
}
