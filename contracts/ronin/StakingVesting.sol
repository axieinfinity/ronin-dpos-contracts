// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStakingVesting.sol";
import "../extensions/collections/HasContracts.sol";
import "../extensions/RONTransferHelper.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";

contract StakingVesting is IStakingVesting, HasValidatorDeprecated, HasContracts, RONTransferHelper, Initializable {
  /// @dev The block bonus for the block producer whenever a new block is mined.
  uint256 internal _blockProducerBonusPerBlock;
  /// @dev The block bonus for the bridge operator whenever a new block is mined.
  uint256 internal _bridgeOperatorBonusPerBlock;
  /// @dev The last block number that the staking vesting sent.
  uint256 internal _lastBlockSendingBonus;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address validatorContract,
    uint256 blockProducerBonusPerBlock,
    uint256 bridgeOperatorBonusPerBlock
  ) external payable initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
    _setBlockProducerBonusPerBlock(blockProducerBonusPerBlock);
    _setBridgeOperatorBonusPerBlock(bridgeOperatorBonusPerBlock);
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
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
  function lastBlockSendingBonus() external view returns (uint256) {
    return _lastBlockSendingBonus;
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
    returns (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus)
  {
    if (block.number <= _lastBlockSendingBonus) revert ErrBonusAlreadySent();

    _lastBlockSendingBonus = block.number;

    blockProducerBonus = forBlockProducer ? blockProducerBlockBonus(block.number) : 0;
    bridgeOperatorBonus = forBridgeOperator ? bridgeOperatorBlockBonus(block.number) : 0;

    uint256 _totalAmount = blockProducerBonus + bridgeOperatorBonus;

    if (_totalAmount > 0) {
      address payable validatorContractAddr = payable(msg.sender);

      success = _unsafeSendRON(validatorContractAddr, _totalAmount);

      if (!success) {
        emit BonusTransferFailed(
          block.number,
          validatorContractAddr,
          blockProducerBonus,
          bridgeOperatorBonus,
          address(this).balance
        );
        return (success, 0, 0);
      }

      emit BonusTransferred(block.number, validatorContractAddr, blockProducerBonus, bridgeOperatorBonus);
    }
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setBlockProducerBonusPerBlock(uint256 amount) external override onlyAdmin {
    _setBlockProducerBonusPerBlock(amount);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setBridgeOperatorBonusPerBlock(uint256 amount) external override onlyAdmin {
    _setBridgeOperatorBonusPerBlock(amount);
  }

  /**
   * @dev Sets the bonus amount per block for block producer.
   *
   * Emits the event `BlockProducerBonusPerBlockUpdated`.
   *
   */
  function _setBlockProducerBonusPerBlock(uint256 amount) internal {
    _blockProducerBonusPerBlock = amount;
    emit BlockProducerBonusPerBlockUpdated(amount);
  }

  /**
   * @dev Sets the bonus amount per block for bridge operator.
   *
   * Emits the event `BridgeOperatorBonusPerBlockUpdated`.
   *
   */
  function _setBridgeOperatorBonusPerBlock(uint256 amount) internal {
    _bridgeOperatorBonusPerBlock = amount;
    emit BridgeOperatorBonusPerBlockUpdated(amount);
  }
}
