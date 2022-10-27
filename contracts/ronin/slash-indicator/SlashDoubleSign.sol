// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/ISlashDoubleSign.sol";
import "../../precompile-usages/PrecompileUsageValidateDoubleSign.sol";
import "../../extensions/collections/HasValidatorContract.sol";

abstract contract SlashDoubleSign is ISlashDoubleSign, HasValidatorContract, PrecompileUsageValidateDoubleSign {
  /// @dev The number of blocks that the current block can be ahead of the double signed blocks.
  uint256 internal _doubleSigningConstrainBlocks;
  /// @dev The amount of RON to slash double sign.
  uint256 internal _slashDoubleSignAmount;
  /// @dev The block number that the punished validator will be jailed until, due to double signing.
  uint256 internal _doubleSigningJailUntilBlock;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function slashDoubleSign(
    address _consensuAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external override {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller must be coinbase");
    if (!_shouldSlash(_consensuAddr)) {
      return;
    }

    if (_pcValidateEvidence(_header1, _header2)) {
      uint256 _period = _validatorContract.currentPeriod();
      emit Slashed(_consensuAddr, SlashType.DOUBLE_SIGNING, _period);
      _validatorContract.slash(_consensuAddr, _doubleSigningJailUntilBlock, _slashDoubleSignAmount);
    }
  }

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function getDoubleSignSlashConfigs()
    external
    view
    override
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    return (_doubleSigningConstrainBlocks, _slashDoubleSignAmount, _doubleSigningJailUntilBlock);
  }

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function setDoubleSignSlashConfigs(
    uint256 _constrainBlocks,
    uint256 _slashAmount,
    uint256 _jailUntilBlock
  ) external override {
    _setDoubleSignSlashConfigs(_constrainBlocks, _slashAmount, _jailUntilBlock);
  }

  /**
   * @dev See `ISlashDoubleSign-setDoubleSignSlashConfigs`.
   */
  function _setDoubleSignSlashConfigs(
    uint256 _constrainBlocks,
    uint256 _slashAmount,
    uint256 _jailUntilBlock
  ) internal {
    _doubleSigningConstrainBlocks = _constrainBlocks;
    _slashDoubleSignAmount = _slashAmount;
    _doubleSigningJailUntilBlock = _jailUntilBlock;
    emit DoubleSignSlashConfigsUpdated(_constrainBlocks, _slashAmount, _jailUntilBlock);
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(address _addr) internal view virtual returns (bool);
}
