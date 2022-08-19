// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashIndicator {

  struct Indicator {	
    /// @dev The block height that the indicator get updated, make sure this update once each block
    uint256 height; 
    
    /// @dev Number of missed block the validator, should not be get decreased to keep track the 
    /// misbehavior records the validator. 
    uint256 counter;
  }

  /**
   * @notice Slash for inavailability
   *
   * @dev Increase the counter of validator with valAddr. If the counter passes the threshold, call 
   * the function from Validators.sol
   * 
   * Requirements:
   * - Only coinbase can call this method
   *
   */
  function slash(address valAddr) external;

  /**
   * @dev Reset the counter of the validator everyday
   *
   * Requirements:
   * - Only validator can call this method
   */
  function resetCounter() external;

  /**
   * @notice Slash for double signing
   *
   * @dev Verify the evidence, call the function from Validators.sol
   *
   * Requirements:
   * - Only coinbase can call this method
   * 
   */
  function slashDoubleSign (address valAddr, bytes calldata evidence) external;


  ///
  /// QUERY FUNCTIONS
  ///

  /**
   * @notice Get slash indicator of a validator
   */
  function getSlashIndicator(address validator) external view returns (uint256 height, uint256 counter);
}

