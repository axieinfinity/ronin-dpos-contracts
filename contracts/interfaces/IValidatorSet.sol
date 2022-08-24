// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/**
 * @title Set of validators in current epoch
 * @notice This contract maintains set of validator in the current epoch of Ronin network
 */
interface IValidatorSet {
  struct Validator {
    /// @dev Address of the validator that produces block, e.g. block.coinbase
    address consensusAddr;
    /// @dev Address of treasury of the validator, used for double-checking validator information
    address treasuryAddr;
    /// @dev State if the validator is in jail
    bool jailed;
    /// @dev For upgrability purpose
    /// @custom:note Consider leave or keep this attribute
    uint256[20] ___gap;
  }

  /**
   * @notice The block producer update the validator set at the end of each epoch.
   *
   * @dev This method is called at the end of each epoch by comparing on `block.number`. The next
   * validator set is not sent by the validator, but is fetched and calculated from `Stake.sol`
   * contract. The order in the set of the validator is also the order to mining block in the next
   * epoch. Voting power (VP) of each validator only affects their shared mining reward.
   *
   * @custom:note Consider only allowing coinbase to call this method
   */
  function updateValidators() external returns (address[] memory);

  /**
   * @notice The block producers call this method to send the mining reward in coinbase transaction.
   *
   * @dev Requirements:
   * - Only coinbase address can call this method
   **/
  function depositReward() external payable;

  /**
   * @notice Slash the validator that missed 50 block a day
   *
   * @dev Requirements:
   * - Only slash contract can call this method
   */
  function slashMisdemeanor(address validator) external;

  /**
   * @notice Slash the validator that missed 150 block a day
   *
   * @dev Requirements:
   * - Only slash contract can call this method
   */
  function slashFelony(address validator) external;

  /**
   * @notice Slash the validator that created 2 blocks on a same height
   *
   * @dev Requirements:
   * - Only slash contract can call this method
   */
  function slashDoubleSign(address validator) external;

  ///
  /// QUERY FUNCTIONS
  ///

  /**
   * @notice All validators call this method to get the set of validators in current epoch.
   * Primarily, this method will be called at the beginning of each epoch.
   */
  function getValidators() external view returns (address[] memory);

  /**
   * @notice Check if an address is in the validator list of the current epoch
   */
  function isCurrentValidator(address validator) external view returns (bool);

  /**
   * @notice Return last block height when the set of validators is updated
   */
  function getLastUpdated() external view returns (uint256 height);
}
