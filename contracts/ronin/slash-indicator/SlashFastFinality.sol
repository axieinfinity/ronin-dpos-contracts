// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/slash-indicator/ISlashFastFinality.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IRoninTrustedOrganization } from "../../interfaces/IRoninTrustedOrganization.sol";
import "../../precompile-usages/PCUValidateFastFinality.sol";
import "../../extensions/collections/HasContracts.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "../../utils/CommonErrors.sol";

abstract contract SlashFastFinality is
  ISlashFastFinality,
  HasContracts,
  HasValidatorDeprecated,
  PCUValidateFastFinality
{
  /// @dev The amount of RON to slash fast finality.
  uint256 internal _slashFastFinalityAmount;
  /// @dev The block number that the punished validator will be jailed until, due to malicious fast finality.
  uint256 internal _fastFinalityJailUntilBlock;
  /// @dev Recording of submitted proof to prevent relay attack.
  mapping(bytes32 => bool) _submittedEvidence;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[48] private ______gap;

  modifier onlyGoverningValidator() {
    if (_getGovernorWeight(msg.sender) == 0) revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    _;
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function slashFastFinality(
    address consensusAddr,
    bytes memory voterPublicKey,
    uint256 targetBlockNumber,
    bytes32[2] memory targetBlockHash,
    bytes[][2] memory listOfPublicKey,
    bytes[2] memory aggregatedSignature
  ) external override onlyGoverningValidator {
    IProfile profileContract = IProfile(getContract(ContractType.PROFILE));
    bytes memory expectingPubKey = (profileContract.getId2Profile(consensusAddr)).pubkey;
    if (keccak256(voterPublicKey) != keccak256(expectingPubKey)) revert ErrInvalidArguments(msg.sig);

    if (
      _pcValidateFastFinalityEvidence(
        voterPublicKey,
        targetBlockNumber,
        targetBlockHash,
        listOfPublicKey,
        aggregatedSignature
      )
    ) {
      IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
      uint256 period = validatorContract.currentPeriod();
      emit Slashed(consensusAddr, SlashType.FAST_FINALITY, period);
      validatorContract.execSlash(consensusAddr, _fastFinalityJailUntilBlock, _slashFastFinalityAmount, true);
    }
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function getFastFinalitySlashingConfigs()
    external
    view
    override
    returns (uint256 slashFastFinalityAmount_, uint256 fastFinalityJailUntilBlock_)
  {
    return (_slashFastFinalityAmount, _fastFinalityJailUntilBlock);
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function setFastFinalitySlashingConfigs(uint256 slashAmount, uint256 jailUntilBlock) external override onlyAdmin {
    _setFastFinalitySlashingConfigs(slashAmount, jailUntilBlock);
  }

  /**
   * @dev See `ISlashFastFinality-setFastFinalitySlashingConfigs`.
   */
  function _setFastFinalitySlashingConfigs(uint256 slashAmount, uint256 jailUntilBlock) internal {
    _slashFastFinalityAmount = slashAmount;
    _fastFinalityJailUntilBlock = jailUntilBlock;
    emit FastFinalitySlashingConfigsUpdated(slashAmount, jailUntilBlock);
  }

  function _getGovernorWeight(address addr) internal view returns (uint256) {
    return IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getGovernorWeight(addr);
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(address _addr) internal view virtual returns (bool);
}
