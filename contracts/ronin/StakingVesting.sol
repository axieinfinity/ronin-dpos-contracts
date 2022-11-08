// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStakingVesting.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../extensions/RONTransferHelper.sol";

contract StakingVesting is IStakingVesting, HasValidatorContract, RONTransferHelper, Initializable {
  /// @dev The block bonus for the block producer whenever a new block is mined.
  uint256 internal _blockProducerBonusPerBlock;
  /// @dev The block bonus for the bridge operator whenever a new block is mined.
  uint256 internal _bridgeOperatorBonusPerBlock;
  /// @dev The last block number that the staking vesting sent.
  uint256 public lastBlockSendingBonus;

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
    _setValidatorContract(__validatorContract);
    _setBlockProducerBonusPerBlock(__blockProducerBonusPerBlock);
    _setBridgeOperatorBonusPerBlock(__bridgeOperatorBonusPerBlock);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IStakingVesting
   */
  function blockProducerBlockBonus(
    uint256 /* _block */
  ) public view override returns (uint256) {
    return _blockProducerBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function bridgeOperatorBlockBonus(
    uint256 /* _block */
  ) public view override returns (uint256) {
    return _bridgeOperatorBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBonus(bool _forBlockProducer, bool _forBridgeOperator)
    external
    override
    onlyValidatorContract
    returns (
      bool _success,
      uint256 _blockProducerBonus,
      uint256 _bridgeOperatorBonus
    )
  {
    require(block.number > lastBlockSendingBonus, "StakingVesting: bonus for already sent");
    lastBlockSendingBonus = block.number;

    _blockProducerBonus = _forBlockProducer ? blockProducerBlockBonus(block.number) : 0;
    _bridgeOperatorBonus = _forBridgeOperator ? bridgeOperatorBlockBonus(block.number) : 0;

    uint256 _totalAmount = _blockProducerBonus + _bridgeOperatorBonus;

    if (_totalAmount > 0) {
      address payable _validatorContractAddr = payable(validatorContract());

      _success = _unsafeSendRON(_validatorContractAddr, _totalAmount);

      if (!_success) {
        emit BonusTransferFailed(
          block.number,
          _validatorContractAddr,
          _blockProducerBonus,
          _bridgeOperatorBonus,
          address(this).balance
        );
        return (_success, 0, 0);
      }

      emit BonusTransferred(block.number, _validatorContractAddr, _blockProducerBonus, _bridgeOperatorBonus);
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
}
