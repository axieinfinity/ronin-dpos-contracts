// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./BaseRoninValidatorSet.sol";
import "./RoninValidatorSetCoinbase.sol";
import "./RoninValidatorSetSlashing.sol";

contract RoninValidatorSet is RoninValidatorSetCoinbase, RoninValidatorSetSlashing, Initializable {
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
    uint256 __numberOfBlocksInEpoch
  ) external initializer {
    _setSlashIndicatorContract(__slashIndicatorContract);
    _setStakingContract(__stakingContract);
    _setStakingVestingContract(__stakingVestingContract);
    _setMaintenanceContract(__maintenanceContract);
    _setBridgeTrackingContract(__bridgeTrackingContract);
    _setRoninTrustedOrganizationContract(__roninTrustedOrganizationContract);
    _setMaxValidatorNumber(__maxValidatorNumber);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setMaxPrioritizedValidatorNumber(__maxPrioritizedValidatorNumber);
    _setNumberOfBlocksInEpoch(__numberOfBlocksInEpoch);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function currentPeriod()
    public
    view
    virtual
    override(RoninValidatorSetCommon, RoninValidatorSetCoinbaseHelper)
    returns (uint256)
  {
    return RoninValidatorSetCommon.currentPeriod();
  }
}
