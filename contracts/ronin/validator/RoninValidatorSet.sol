// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "./CoinbaseExecution.sol";
import "./SlashingExecution.sol";

// IRoninValidatorSet
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
    _setMinEffectiveDaysOnwards(__minEffectiveDaysOnwards);
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  /**
   * @dev Only receives RON from staking vesting contract (for topping up bonus), and from staking contract (for transferring
   * deducting amount when slash).
   */
  function _fallback() internal view {
    require(
      msg.sender == stakingVestingContract() || msg.sender == stakingContract(),
      "RoninValidatorSet: only receives RON from staking vesting contract or staking contract"
    );
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function bridgeOperatorOf(address _consensusAddr)
    public
    view
    override(CoinbaseExecution, IValidatorInfo, ValidatorInfoStorage)
    returns (address)
  {
    return super.bridgeOperatorOf(_consensusAddr);
  }
}
