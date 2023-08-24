// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStakingVesting.sol";
import "../extensions/collections/HasContracts.sol";
import "../extensions/consumers/PercentageConsumer.sol";
import { RONTransferHelper } from "../extensions/RONTransferHelper.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import "../utils/CommonErrors.sol";

contract StakingVesting is
  IStakingVesting,
  PercentageConsumer,
  HasValidatorDeprecated,
  HasContracts,
  Initializable,
  RONTransferHelper
{
  /// @dev The block bonus for the block producer whenever a new block is mined.
  uint256 internal _blockProducerBonusPerBlock;
  /// @dev The block bonus for the bridge operator whenever a new block is mined.
  uint256 internal _bridgeOperatorBonusPerBlock;
  /// @dev The last block number that the staking vesting sent.
  uint256 public lastBlockSendingBonus;
  /// @dev The percentage that extracted from reward of block producer for fast finality.
  uint256 internal _fastFinalityRewardPercentage;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 __blockProducerBonusPerBlock,
    uint256 __bridgeOperatorBonusPerBlock
  ) external payable initializer {
    _setContract(ContractType.VALIDATOR, __validatorContract);
    _setBlockProducerBonusPerBlock(__blockProducerBonusPerBlock);
    _setBridgeOperatorBonusPerBlock(__bridgeOperatorBonusPerBlock);
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  function initializeV3(uint256 fastFinalityRewardPercent) external reinitializer(3) {
    _setFastFinalityRewardPercentage(fastFinalityRewardPercent);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IStakingVesting
   */
  function blockProducerBlockBonus(uint256 /* _block */) public view override returns (uint256) {
    return _blockProducerBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function bridgeOperatorBlockBonus(uint256 /* _block */) public view override returns (uint256) {
    return _bridgeOperatorBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function fastFinalityRewardPercentage() external view override returns (uint256) {
    return _fastFinalityRewardPercentage;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBonus(
    bool forBlockProducer,
    bool forBridgeOperator
  )
    external
    override
    onlyContract(ContractType.VALIDATOR)
    returns (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus, uint256 fastFinalityRewardPercent)
  {
    if (block.number <= lastBlockSendingBonus) revert ErrBonusAlreadySent();

    lastBlockSendingBonus = block.number;

    blockProducerBonus = forBlockProducer ? blockProducerBlockBonus(block.number) : 0;
    bridgeOperatorBonus = forBridgeOperator ? bridgeOperatorBlockBonus(block.number) : 0;
    fastFinalityRewardPercent = _fastFinalityRewardPercentage;

    uint256 totalAmount = blockProducerBonus + bridgeOperatorBonus;

    if (totalAmount > 0) {
      address payable validatorContractAddr = payable(msg.sender);

      success = _unsafeSendRON(validatorContractAddr, totalAmount);

      if (!success) {
        emit BonusTransferFailed(
          block.number,
          validatorContractAddr,
          blockProducerBonus,
          bridgeOperatorBonus,
          address(this).balance
        );
        return (success, 0, 0, 0);
      }

      emit BonusTransferred(block.number, validatorContractAddr, blockProducerBonus, bridgeOperatorBonus);
    }
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setBlockProducerBonusPerBlock(uint256 _amount) external override onlyAdmin {
    _setBlockProducerBonusPerBlock(_amount);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setBridgeOperatorBonusPerBlock(uint256 _amount) external override onlyAdmin {
    _setBridgeOperatorBonusPerBlock(_amount);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setFastFinalityRewardPercentage(uint256 percent) external override onlyAdmin {
    if (percent > _MAX_PERCENTAGE) revert ErrInvalidArguments(msg.sig);
    _setFastFinalityRewardPercentage(percent);
  }

  /**
   * @dev Sets the bonus amount per block for block producer.
   *
   * Emits the event `BlockProducerBonusPerBlockUpdated`.
   *
   */
  function _setBlockProducerBonusPerBlock(uint256 _amount) internal {
    _blockProducerBonusPerBlock = _amount;
    emit BlockProducerBonusPerBlockUpdated(_amount);
  }

  /**
   * @dev Sets the bonus amount per block for bridge operator.
   *
   * Emits the event `BridgeOperatorBonusPerBlockUpdated`.
   *
   */
  function _setBridgeOperatorBonusPerBlock(uint256 _amount) internal {
    _bridgeOperatorBonusPerBlock = _amount;
    emit BridgeOperatorBonusPerBlockUpdated(_amount);
  }

  /**
   * @dev Sets the percent of fast finality reward.
   *
   * Emits the event `FastFinalityRewardPercentageUpdated`.
   *
   */
  function _setFastFinalityRewardPercentage(uint256 percent) internal {
    _fastFinalityRewardPercentage = percent;
    emit FastFinalityRewardPercentageUpdated(percent);
  }
}
