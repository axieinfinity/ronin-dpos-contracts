// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasRoninGovernanceAdminContract.sol";
import "../../interfaces/IRoninGovernanceAdmin.sol";

contract HasRoninGovernanceAdminContract is IHasRoninGovernanceAdminContract, HasProxyAdmin {
  IRoninGovernanceAdmin internal _roninGovernanceAdminContract;

  modifier onlyRoninGovernanceAdminContract() {
    require(
      roninGovernanceAdminContract() == msg.sender,
      "HasRoninGovernanceAdminContract: method caller must be ronin governance admin contract"
    );
    _;
  }

  /**
   * @inheritdoc IHasRoninGovernanceAdminContract
   */
  function roninGovernanceAdminContract() public view override returns (address) {
    return address(_roninGovernanceAdminContract);
  }

  /**
   * @inheritdoc IHasRoninGovernanceAdminContract
   */
  function setRoninGovernanceAdminContract(address _addr) external override onlyAdmin {
    require(_addr.code.length > 0, "HasRoninGovernanceAdminContract: set to non-contract");
    _setRoninGovernanceAdminContract(_addr);
  }

  /**
   * @dev Sets the ronin governance admin contract.
   *
   * Emits the event `RoninGovernanceAdminContractUpdated`.
   *
   */
  function _setRoninGovernanceAdminContract(address _addr) internal {
    _roninGovernanceAdminContract = IRoninGovernanceAdmin(_addr);
    emit RoninGovernanceAdminContractUpdated(_addr);
  }
}
