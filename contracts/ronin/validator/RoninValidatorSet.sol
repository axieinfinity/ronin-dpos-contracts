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
   * @dev Withdraw the deprecated rewards e.g. the rewards that get deprecated when validator is slashed, maintained.
   * The withdraw target is the staking vesting contract.
   *
   * Requirement:
   * - The method caller must be the admin
   */
  function withdrawDeprecatedReward() external onlyAdmin {
    uint256 _withdrawAmount = _totalDeprecatedReward;
    address _withdrawTarget = stakingVestingContract();

    _totalDeprecatedReward = 0;

    (bool _success, ) = _withdrawTarget.call{ value: _withdrawAmount }(
      abi.encodeWithSelector(IStakingVesting.receiveRON.selector)
    );

    require(_success, "RoninValidatorSet: cannot transfer deprecated reward to staking vesting contract");

    emit DeprecatedRewardWithdrawn(_withdrawTarget, _withdrawAmount);
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

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr)
    internal
    view
    override(CoinbaseExecution, ValidatorInfoStorage)
    returns (address)
  {
    return CoinbaseExecution._bridgeOperatorOf(_consensusAddr);
  }
}
