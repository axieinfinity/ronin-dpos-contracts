// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasValidatorContract.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";

contract HasValidatorContract is IHasValidatorContract, HasProxyAdmin {
  IRoninValidatorSet internal _validatorContract;

  modifier onlyValidatorContract() {
    require(validatorContract() == msg.sender, "HasValidatorContract: method caller must be validator contract");
    _;
  }

  /**
   * @inheritdoc IHasValidatorContract
   */
  function validatorContract() public view override returns (address) {
    return address(_validatorContract);
  }

  /**
   * @inheritdoc IHasValidatorContract
   */
  function setValidatorContract(address _addr) external override onlyAdmin {
    require(_addr.code.length > 0, "HasValidatorContract: set to non-contract");
    _setValidatorContract(_addr);
  }

  /**
   * @dev Sets the validator contract.
   *
   * Emits the event `ValidatorContractUpdated`.
   *
   */
  function _setValidatorContract(address _addr) internal {
    _validatorContract = IRoninValidatorSet(_addr);
    emit ValidatorContractUpdated(_addr);
  }
}
