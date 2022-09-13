// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStakingVesting.sol";

contract StakingVesting is Initializable, IStakingVesting {
  /// @dev The block bonus whenever a new block is mined.
  uint256 internal _bonusPerBlock;
  /// @dev The last block number that the bonus reward sent.
  uint256 public lastBonusSentBlock;
  /// @dev Validator contract address.
  address internal _validatorContract;

  modifier onlyValidatorContract() {
    require(msg.sender == _validatorContract, "Staking: method caller is not the validator contract");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  receive() external payable onlyValidatorContract {}

  fallback() external payable onlyValidatorContract {}

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(uint256 __bonusPerBlock, address __validatorContract) external payable initializer {
    _setBonusPerBlock(__bonusPerBlock);
    _setValidatorContract(__validatorContract);
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

    require(_block > lastBonusSentBlock, "Staking: bonus already sent");
    _amount = blockBonus(_block);

    if (_amount > 0) {
      (bool _success, ) = payable(_validatorContract).call{ value: _amount }("");
      require(_success, "Staking: could not transfer RON to validator contract");
      emit BlockBonusTransferred(_block, _validatorContract, _amount);
    }

    lastBonusSentBlock = _block;
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

  /**
   * @dev Sets the governance admin address.
   *
   * Emits the `ValidatorContractUpdated` event.
   *
   */
  function _setValidatorContract(address _newValidatorContract) internal {
    _validatorContract = _newValidatorContract;
    emit ValidatorContractUpdated(_newValidatorContract);
  }
}
