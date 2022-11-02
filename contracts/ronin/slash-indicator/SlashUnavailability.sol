// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./CreditScore.sol";
import "../../interfaces/slash-indicator/ISlashUnavailability.sol";
import "../../extensions/collections/HasValidatorContract.sol";

abstract contract SlashUnavailability is ISlashUnavailability, HasValidatorContract {
  /// @dev The last block that a validator is slashed for unavailability.
  uint256 public lastUnavailabilitySlashedBlock;
  /// @dev Mapping from validator address => period index => unavailability indicator.
  mapping(address => mapping(uint256 => uint256)) internal _unavailabilityIndicator;

  /// @dev The mining reward will be deprecated, if (s)he missed more than this threshold.
  uint256 internal _unavailabilityTier1Threshold;
  /**
   * @dev The mining reward will be deprecated, (s)he will be put in jailed, and will be deducted
   * self-staking if (s)he misses more than this threshold.
   */
  uint256 internal _unavailabilityTier2Threshold;
  /// @dev The amount of RON to deduct from self-staking of a block producer when (s)he is slashed tier-2.
  uint256 internal _slashAmountForUnavailabilityTier2Threshold;
  /// @dev The number of blocks to jail a block producer when (s)he is slashed tier-2.
  uint256 internal _jailDurationForUnavailabilityTier2Threshold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  modifier oncePerBlock() {
    require(
      block.number > lastUnavailabilitySlashedBlock,
      "SlashIndicator: cannot slash a validator twice or slash more than one validator in one block"
    );
    lastUnavailabilitySlashedBlock = block.number;
    _;
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function slashUnavailability(address _validatorAddr) external override oncePerBlock {
    require(msg.sender == block.coinbase, "SlashUnavailability: method caller must be coinbase");
    if (!_shouldSlash(_validatorAddr)) {
      return;
    }

    uint256 _period = _validatorContract.currentPeriod();
    uint256 _count = ++_unavailabilityIndicator[_validatorAddr][_period];

    if (_count == _unavailabilityTier2Threshold) {
      emit Slashed(_validatorAddr, SlashType.UNAVAILABILITY_TIER_2, _period);
      _validatorContract.slash(
        _validatorAddr,
        block.number + _jailDurationForUnavailabilityTier2Threshold,
        _slashAmountForUnavailabilityTier2Threshold
      );
    } else if (_count == _unavailabilityTier1Threshold) {
      emit Slashed(_validatorAddr, SlashType.UNAVAILABILITY_TIER_1, _period);
      _validatorContract.slash(_validatorAddr, 0, 0);
    }
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function setUnavailabilitySlashingConfigs(
    uint256 _tier1Threshold,
    uint256 _tier2Threshold,
    uint256 _slashAmountForTier2Threshold,
    uint256 _jailDurationForTier2Threshold
  ) external override onlyAdmin {
    _setUnavailabilitySlashingConfigs(
      _tier1Threshold,
      _tier2Threshold,
      _slashAmountForTier2Threshold,
      _jailDurationForTier2Threshold
    );
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function getUnavailabilitySlashingConfigs()
    external
    view
    override
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      _unavailabilityTier1Threshold,
      _unavailabilityTier2Threshold,
      _slashAmountForUnavailabilityTier2Threshold,
      _jailDurationForUnavailabilityTier2Threshold
    );
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function currentUnavailabilityIndicator(address _validator) external view override returns (uint256) {
    return getUnavailabilityIndicator(_validator, _validatorContract.currentPeriod());
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _unavailabilityIndicator[_validator][_period];
  }

  /**
   * @dev Sets the unavailability indicator of the `_validator` at `_period`.
   */
  function _setUnavailabilityIndicator(
    address _validator,
    uint256 _period,
    uint256 _indicator
  ) internal virtual {
    _unavailabilityIndicator[_validator][_period] = _indicator;
  }

  /**
   * @dev See `ISlashUnavailability-setUnavailabilitySlashingConfigs`.
   */
  function _setUnavailabilitySlashingConfigs(
    uint256 _tier1Threshold,
    uint256 _tier2Threshold,
    uint256 _slashAmountForTier2Threshold,
    uint256 _jailDurationForTier2Threshold
  ) internal {
    require(_unavailabilityTier1Threshold <= _unavailabilityTier2Threshold, "SlashUnavailability: invalid threshold");
    _unavailabilityTier1Threshold = _tier1Threshold;
    _unavailabilityTier2Threshold = _tier2Threshold;
    _slashAmountForUnavailabilityTier2Threshold = _slashAmountForTier2Threshold;
    _jailDurationForUnavailabilityTier2Threshold = _jailDurationForTier2Threshold;
    emit UnavailabilitySlashingConfigsUpdated(
      _tier1Threshold,
      _tier2Threshold,
      _slashAmountForTier2Threshold,
      _jailDurationForTier2Threshold
    );
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(address _addr) internal view virtual returns (bool);
}
