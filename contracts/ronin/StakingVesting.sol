// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStakingVesting.sol";
import "../extensions/HasValidatorContract.sol";
import "../extensions/RONTransferHelper.sol";

contract StakingVesting is IStakingVesting, HasValidatorContract, RONTransferHelper, Initializable {
  /// @dev The block bonus whenever a new block is mined.
  uint256 internal _bonusPerBlock;
  /// @dev The last block number that the bonus reward sent.
  uint256 public lastBonusSentBlock;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address __validatorContract, uint256 __bonusPerBlock) external payable initializer {
    _setValidatorContract(__validatorContract);
    _setBonusPerBlock(__bonusPerBlock);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IStakingVesting
   */
  function blockBonus(
    uint256 /* _block */
  ) public view returns (uint256) {
    return _bonusPerBlock;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBlockBonus() external onlyValidatorContract returns (uint256 _amount) {
    uint256 _block = block.number;

    require(_block > lastBonusSentBlock, "StakingVesting: bonus already sent");
    lastBonusSentBlock = _block;
    _amount = blockBonus(_block);

    if (_amount > 0) {
      address payable _validatorContractAddr = payable(validatorContract());
      require(
        _sendRON(_validatorContractAddr, _amount),
        "StakingVesting: could not transfer RON to validator contract"
      );
      emit BlockBonusTransferred(_block, _validatorContractAddr, _amount);
    }
  }

  /**
   * @dev Sets the bonus amount per block.
   *
   * Emits the event `BonusPerBlockUpdated`.
   *
   */
  function _setBonusPerBlock(uint256 _amount) internal {
    _bonusPerBlock = _amount;
    emit BonusPerBlockUpdated(_amount);
  }
}
