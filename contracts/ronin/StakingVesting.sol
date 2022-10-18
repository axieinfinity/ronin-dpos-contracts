// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStakingVesting.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../extensions/RONTransferHelper.sol";

contract StakingVesting is IStakingVesting, HasValidatorContract, RONTransferHelper, Initializable {
  /// @dev The block bonus for the validator whenever a new block is mined.
  uint256 internal _validatorBonusPerBlock;
  /// @dev The block bonus for the bridge operator whenever a new block is mined.
  uint256 internal _bridgeOperatorBonusPerBlock;
  /// @dev The last block number that the staking vesting for validator sent.
  uint256 public lastBlockSendingValidatorBonus;
  /// @dev The last block number that the staking vesting for bridge operator sent.
  uint256 public lastBlockSendingBridgeOperatorBonus;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 __validatorBonusPerBlock,
    uint256 __bridgeOperatorBonusPerBlock
  ) external payable initializer {
    _setValidatorContract(__validatorContract);
    _setValidatorBonusPerBlock(__validatorBonusPerBlock);
    _setBridgeOperatorBonusPerBlock(__bridgeOperatorBonusPerBlock);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IStakingVesting
   */
  function validatorBlockBonus(
    uint256 /* _block */
  ) public view returns (uint256) {
    return _validatorBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function bridgeOperatorBlockBonus(
    uint256 /* _block */
  ) public view returns (uint256) {
    return _bridgeOperatorBonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBonus()
    external
    onlyValidatorContract
    returns (uint256 _validatorBonus, uint256 _bridgeOperatorBonus)
  {
    _validatorBonus = requestValidatorBonus();
    _bridgeOperatorBonus = requestBridgeOperatorBonus();
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestValidatorBonus() public onlyValidatorContract returns (uint256 _amount) {
    require(block.number > lastBlockSendingValidatorBonus, "StakingVesting: bonus for validator already sent");
    lastBlockSendingValidatorBonus = block.number;
    _amount = validatorBlockBonus(block.number);

    if (_amount > 0) {
      address payable _validatorContractAddr = payable(validatorContract());
      require(
        _sendRON(_validatorContractAddr, _amount),
        "StakingVesting: could not transfer RON to validator contract"
      );
      emit ValidatorBonusTransferred(block.number, _validatorContractAddr, _amount);
    }
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBridgeOperatorBonus() public onlyValidatorContract returns (uint256 _amount) {
    require(
      block.number > lastBlockSendingBridgeOperatorBonus,
      "StakingVesting: bonus for bridge operator already sent"
    );
    lastBlockSendingBridgeOperatorBonus = block.number;
    _amount = bridgeOperatorBlockBonus(block.number);

    if (_amount > 0) {
      address payable _validatorContractAddr = payable(validatorContract());
      require(
        _sendRON(_validatorContractAddr, _amount),
        "StakingVesting: could not transfer RON to validator contract"
      );
      emit BridgeOperatorBonusTransferred(block.number, _validatorContractAddr, _amount);
    }
  }

  /**
   * @dev Sets the bonus amount per block for validator.
   *
   * Emits the event `ValidatorBonusPerBlockUpdated`.
   *
   */
  function _setValidatorBonusPerBlock(uint256 _amount) internal {
    _validatorBonusPerBlock = _amount;
    emit ValidatorBonusPerBlockUpdated(_amount);
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
