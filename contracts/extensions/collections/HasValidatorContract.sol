// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasValidatorContract.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";

contract HasValidatorContract is IHasValidatorContract, HasProxyAdmin {
  IRoninValidatorSet internal _validatorContract;

  modifier onlyValidatorContract() {
    _requireValidatorContract();
    _;
  }

  function _requireValidatorContract() private view {
    if (validatorContract() != msg.sender) revert ErrUnauthorized(msg.sig, Role.VALIDATOR_CONTRACT);
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
  function setValidatorContract(address _addr) external virtual override onlyAdmin {
    if (_addr.code.length == 0) revert ErrZeroCodeContract(msg.sig);
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
