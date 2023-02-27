// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/slash-indicator/ISlashDoubleSign.sol";
import "../../precompile-usages/PCUValidateDoubleSign.sol";
import "../../extensions/collections/HasValidatorContract.sol";

abstract contract SlashDoubleSign is ISlashDoubleSign, HasValidatorContract, PCUValidateDoubleSign {
  /// @dev The amount of RON to slash double sign.
  uint256 internal _slashDoubleSignAmount;
  /// @dev The block number that the punished validator will be jailed until, due to double signing.
  uint256 internal _doubleSigningJailUntilBlock;
  /// @dev Recording of submitted proof to prevent relay attack.
  mapping(bytes32 => bool) _submittedEvidence;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[49] private ______gap;

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function slashDoubleSign(
    address _consensusAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external override onlyAdmin {
    require(_shouldSlash(_consensusAddr), "SlashDoubleSign: invalid slashee");

    bytes32 _header1Checksum = keccak256(_header1);
    bytes32 _header2Checksum = keccak256(_header2);

    require(
      !_submittedEvidence[_header1Checksum] && !_submittedEvidence[_header2Checksum],
      "SlashDoubleSign: evidence already submitted"
    );

    if (_pcValidateEvidence(_header1, _header2)) {
      uint256 _period = _validatorContract.currentPeriod();
      _submittedEvidence[_header1Checksum] = true;
      _submittedEvidence[_header2Checksum] = true;
      emit Slashed(_consensusAddr, SlashType.DOUBLE_SIGNING, _period);
      _validatorContract.execSlash(_consensusAddr, _doubleSigningJailUntilBlock, _slashDoubleSignAmount, true);
    }
  }

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function getDoubleSignSlashingConfigs()
    external
    view
    override
    returns (uint256 slashDoubleSignAmount_, uint256 doubleSigningJailUntilBlock_)
  {
    return (_slashDoubleSignAmount, _doubleSigningJailUntilBlock);
  }

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function setDoubleSignSlashingConfigs(uint256 _slashAmount, uint256 _jailUntilBlock) external override onlyAdmin {
    _setDoubleSignSlashingConfigs(_slashAmount, _jailUntilBlock);
  }

  /**
   * @dev See `ISlashDoubleSign-setDoubleSignSlashingConfigs`.
   */
  function _setDoubleSignSlashingConfigs(uint256 _slashAmount, uint256 _jailUntilBlock) internal {
    _slashDoubleSignAmount = _slashAmount;
    _doubleSigningJailUntilBlock = _jailUntilBlock;
    emit DoubleSignSlashingConfigsUpdated(_slashAmount, _jailUntilBlock);
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(address _addr) internal view virtual returns (bool);
}
