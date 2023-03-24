// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IQuorum.sol";
import "./collections/HasProxyAdmin.sol";

abstract contract GatewayV2 is HasProxyAdmin, Pausable, IQuorum {
  uint256 internal _num;
  uint256 internal _denom;

  address private ______deprecated;
  uint256 public nonce;

  address public emergencyPauser;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[49] private ______gap;

  /**
   * @dev Grant emergency pauser role for `_addr`.
   */
  function setEmergencyPauser(address _addr) external onlyAdmin {
    emergencyPauser = _addr;
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _getTotalWeight();
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 _numerator, uint256 _denominator)
    external
    virtual
    onlyAdmin
    returns (uint256, uint256)
  {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @dev Triggers paused state.
   */
  function pause() external {
    require(msg.sender == _getAdmin() || msg.sender == emergencyPauser, "GatewayV2: not authorized pauser");
    _pause();
  }

  /**
   * @dev Triggers unpaused state.
   */
  function unpause() external {
    require(msg.sender == _getAdmin() || msg.sender == emergencyPauser, "GatewayV2: not authorized pauser");
    _unpause();
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    return _minimumVoteWeight(_getTotalWeight());
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(uint256 _numerator, uint256 _denominator)
    internal
    virtual
    returns (uint256 _previousNum, uint256 _previousDenom)
  {
    require(_numerator <= _denominator, "GatewayV2: invalid threshold");
    _previousNum = _num;
    _previousDenom = _denom;
    _num = _numerator;
    _denom = _denominator;
    emit ThresholdUpdated(nonce++, _numerator, _denominator, _previousNum, _previousDenom);
  }

  /**
   * @dev Returns minimum vote weight.
   */
  function _minimumVoteWeight(uint256 _totalWeight) internal view virtual returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @dev Returns the total weight.
   */
  function _getTotalWeight() internal view virtual returns (uint256);
}
