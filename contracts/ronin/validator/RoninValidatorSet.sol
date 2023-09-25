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
    address /* __bridgeTrackingContract */,
    uint256 __maxValidatorNumber,
    uint256 __maxValidatorCandidate,
    uint256 __maxPrioritizedValidatorNumber,
    uint256 __minEffectiveDaysOnwards,
    uint256 __numberOfBlocksInEpoch,
    // __emergencyExitConfigs[0]: emergencyExitLockedAmount
    // __emergencyExitConfigs[1]: emergencyExpiryDuration
    uint256[2] calldata __emergencyExitConfigs
  ) external initializer {
    _setContract(ContractType.SLASH_INDICATOR, __slashIndicatorContract);
    _setContract(ContractType.STAKING, __stakingContract);
    _setContract(ContractType.STAKING_VESTING, __stakingVestingContract);
    _setContract(ContractType.MAINTENANCE, __maintenanceContract);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, __roninTrustedOrganizationContract);

    _setMaxValidatorNumber(__maxValidatorNumber);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setMaxPrioritizedValidatorNumber(__maxPrioritizedValidatorNumber);
    _setMinEffectiveDaysOnwards(__minEffectiveDaysOnwards);
    _setEmergencyExitLockedAmount(__emergencyExitConfigs[0]);
    _setEmergencyExpiryDuration(__emergencyExitConfigs[1]);
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.STAKING, ______deprecatedStakingContract);
    _setContract(ContractType.MAINTENANCE, ______deprecatedMaintenance);
    _setContract(ContractType.SLASH_INDICATOR, ______deprecatedSlashIndicator);
    _setContract(ContractType.STAKING_VESTING, ______deprecatedStakingVesting);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, ______deprecatedTrustedOrg);

    delete ______deprecatedStakingContract;
    delete ______deprecatedMaintenance;
    delete ______deprecatedSlashIndicator;
    delete ______deprecatedStakingVesting;
    delete ______deprecatedBridgeTracking;
    delete ______deprecatedTrustedOrg;
  }

  function initializeV3(address fastFinalityTrackingContract) external reinitializer(3) {
    _setContract(ContractType.FAST_FINALITY_TRACKING, fastFinalityTrackingContract);
  }

  /**
   * @dev Only receives RON from staking vesting contract (for topping up bonus), and from staking contract (for transferring
   * deducting amount on slashing).
   */
  function _fallback() internal view {
    if (msg.sender != getContract(ContractType.STAKING_VESTING) && msg.sender != getContract(ContractType.STAKING)) {
      revert ErrUnauthorizedReceiveRON();
    }
  }
}
