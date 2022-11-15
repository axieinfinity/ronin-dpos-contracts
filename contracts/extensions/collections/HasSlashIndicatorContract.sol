// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasSlashIndicatorContract.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";

contract HasSlashIndicatorContract is IHasSlashIndicatorContract, HasProxyAdmin {
  ISlashIndicator internal _slashIndicatorContract;

  modifier onlySlashIndicatorContract() {
    require(
      slashIndicatorContract() == msg.sender,
      "HasSlashIndicatorContract: method caller must be slash indicator contract"
    );
    _;
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
    require(_addr.code.length > 0, "HasSlashIndicatorContract: set to non-contract");
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
