// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "./fragments/ValidatorSetFragmentCoinbase.sol";
import "./fragments/ValidatorSetFragmentSlashing.sol";

contract RoninValidatorSet is
  Initializable,
  HasStakingVestingContract,
  ValidatorSetFragmentCoinbase,
  ValidatorSetFragmentSlashing
{
  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               OVERRIDING FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  function currentPeriod() public view override(TimingManager, ValidatorSetFragmentCoinbase) returns (uint256) {
    return TimingManager.currentPeriod();
  }

  function numberOfBlocksInEpoch()
    public
    view
    override(TimingManager, ValidatorSetFragmentCoinbase)
    returns (uint256 _numberOfBlocks)
  {
    return TimingManager.numberOfBlocksInEpoch();
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                       MAIN                                        //
  ///////////////////////////////////////////////////////////////////////////////////////

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
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  /**
   * @dev Only receives RON from staking vesting contract.
   */
  function _fallback() internal view {
    require(
      msg.sender == stakingVestingContract(),
      "RoninValidatorSet: only receives RON from staking vesting contract"
    );
  }
}
