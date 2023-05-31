// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasSlashIndicatorContract.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";

contract HasSlashIndicatorContract is IHasSlashIndicatorContract, HasProxyAdmin {
  ISlashIndicator internal _slashIndicatorContract;

  modifier onlySlashIndicatorContract() {
    _requireSlashIndicatorContract();
    _;
  }

  function _requireSlashIndicatorContract() private view {
    if (slashIndicatorContract() != msg.sender) revert ErrUnauthorized(msg.sig, Roles.SLASH_INDICATOR_CONTRACT);
  }

  /**
   * @inheritdoc IHasSlashIndicatorContract
   */
  function slashIndicatorContract() public view override returns (address) {
    return address(_slashIndicatorContract);
  }

  /**
   * @inheritdoc IHasSlashIndicatorContract
   */
  function setSlashIndicatorContract(address _addr) external override onlyAdmin {
    if (_addr.code.length == 0) revert ErrZeroCodeContract(msg.sig);
    _setSlashIndicatorContract(_addr);
  }

  /**
   * @dev Sets the slash indicator contract.
   *
   * Emits the event `SlashIndicatorContractUpdated`.
   *
   */
  function _setSlashIndicatorContract(address _addr) internal {
    _slashIndicatorContract = ISlashIndicator(_addr);
    emit SlashIndicatorContractUpdated(_addr);
  }
}
