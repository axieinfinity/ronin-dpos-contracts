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
  uint256[48] private ______gap;

  /**
   * @inheritdoc ISlashDoubleSign
   */
  function slashDoubleSign(
    TConsensus consensusAddr,
    bytes calldata header1,
    bytes calldata header2
  ) external override onlyAdmin {
    bytes32 header1Checksum = keccak256(header1);
    bytes32 header2Checksum = keccak256(header2);

    if (_submittedEvidence[header1Checksum] || _submittedEvidence[header2Checksum]) {
      revert ErrEvidenceAlreadySubmitted();
    }

    address validatorId = _convertC2P(consensusAddr);

    // Edge case: non-validator who never apply for the candidate role, nor have a profile.
    // Must be slashed by the consensus address, since the validatorId will be address(0).
    if (validatorId == address(0)) {
      validatorId = TConsensus.unwrap(consensusAddr);
    }

    if (_pcValidateEvidence(validatorId, header1, header2)) {
      IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
      uint256 period = validatorContract.currentPeriod();
      _submittedEvidence[header1Checksum] = true;
      _submittedEvidence[header2Checksum] = true;
      emit Slashed(validatorId, SlashType.DOUBLE_SIGNING, period);
      validatorContract.execSlash(validatorId, _doubleSigningJailUntilBlock, _slashDoubleSignAmount, true);
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
  function _shouldSlash(TConsensus consensus, address validatorId) internal view virtual returns (bool);

  function _convertC2P(TConsensus consensusAddr) internal view virtual returns (address);
}
