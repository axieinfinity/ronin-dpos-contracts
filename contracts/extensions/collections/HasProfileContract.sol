// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasProfileContract.sol";
import "../../interfaces/IProfile.sol";

contract HasProfileContract is IHasProfileContract, HasProxyAdmin {
  IProfile internal _profileContract;

  modifier onlyProfileContract() {
    if (profileContract() != msg.sender) revert ErrCallerMustBeProfileContract();
    _;
  }

  /**
   * @inheritdoc IHasProfileContract
   */
  function profileContract() public view override returns (address) {
    return address(_profileContract);
  }

  /**
   * @inheritdoc IHasProfileContract
   */
  function setProfileContract(address _addr) external virtual override onlyAdmin {
    if (_addr.code.length == 0) revert ErrZeroCodeContract();
    _setProfileContract(_addr);
  }

  /**
   * @dev Sets the Profile contract.
   *
   * Emits the event `ProfileContractUpdated`.
   *
   */
  function _setProfileContract(address _addr) internal {
    _profileContract = IProfile(_addr);
    emit ProfileContractUpdated(_addr);
  }
}
