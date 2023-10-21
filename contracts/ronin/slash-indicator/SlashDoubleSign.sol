// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/slash-indicator/ISlashDoubleSign.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../precompile-usages/PCUValidateDoubleSign.sol";
import "../../extensions/collections/HasContracts.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";

abstract contract SlashDoubleSign is ISlashDoubleSign, HasContracts, HasValidatorDeprecated, PCUValidateDoubleSign {
  /// @dev The amount of RON to slash double sign.
  uint256 internal _slashDoubleSignAmount;
  /// @dev The block number that the punished validator will be jailed until, due to double signing.
  uint256 internal _doubleSigningJailUntilBlock;
  /** @dev The offset from the submitted block to the current block, from which double signing will be invalidated.
   * This parameter is exposed for system transaction.
   **/
  uint256 internal _doubleSigningOffsetLimitBlock;
  /// @dev Recording of submitted proof to prevent relay attack.
  mapping(bytes32 => bool) _submittedEvidence;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[24] private ______gap;

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function slashDoubleSign(
    address _consensusAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external override onlyAdmin {
    bytes32 _header1Checksum = keccak256(_header1);
    bytes32 _header2Checksum = keccak256(_header2);

    if (_submittedEvidence[_header1Checksum] || _submittedEvidence[_header2Checksum]) {
      revert ErrEvidenceAlreadySubmitted();
    }

    if (_pcValidateEvidence(_consensusAddr, _header1, _header2)) {
      IRoninValidatorSet _validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
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
    returns (
      uint256 slashDoubleSignAmount_,
      uint256 doubleSigningJailUntilBlock_,
      uint256 doubleSigningOffsetLimitBlock_
    )
  {
    return (_slashDoubleSignAmount, _doubleSigningJailUntilBlock, _doubleSigningOffsetLimitBlock);
  }

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function setDoubleSignSlashingConfigs(
    uint256 _slashAmount,
    uint256 _jailUntilBlock,
    uint256 _offsetLimitBlock
  ) external override onlyAdmin {
    _setDoubleSignSlashingConfigs(_slashAmount, _jailUntilBlock, _offsetLimitBlock);
  }

  /**
   * @dev See `ISlashDoubleSign-setDoubleSignSlashingConfigs`.
   */
  function _setDoubleSignSlashingConfigs(
    uint256 _slashAmount,
    uint256 _jailUntilBlock,
    uint256 _offsetLimitBlock
  ) internal {
    _slashDoubleSignAmount = _slashAmount;
    _doubleSigningJailUntilBlock = _jailUntilBlock;
    _doubleSigningOffsetLimitBlock = _offsetLimitBlock;
    emit DoubleSignSlashingConfigsUpdated(_slashAmount, _jailUntilBlock, _doubleSigningOffsetLimitBlock);
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(address _addr) internal view virtual returns (bool);
}
