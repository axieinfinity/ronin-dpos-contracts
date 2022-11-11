// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRoninValidatorSetCoinbaseHelper {
  ///////////////////////////////////////////////////////////////////////////////////////
  //                           FUNCTIONS FOR EPOCH CONTROL                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the block that validator set was updated.
   */
  function getLastUpdatedBlock() external view returns (uint256);

  /**
   * @dev Returns the epoch index from the block number.
   */
  function epochOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns whether the epoch ending is at the block number `_block`.
   */
  function epochEndingAt(uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the period ending at the current block number.
   */
  function isPeriodEnding() external view returns (bool);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                        QUERY FUNCTIONS ABOUT VALIDATORS                           //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the current validator list.
   */
  function getValidators() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is either a bridge operator or a block producer.
   */
  function isValidator(address _addr) external view returns (bool);

  /**
   * @dev Returns the current block producer list.
   */
  function getBlockProducers() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is block producer or not.
   */
  function isBlockProducer(address _addr) external view returns (bool);

  /**
   * @dev Returns total numbers of the block producers.
   */
  function totalBlockProducers() external view returns (uint256);

  /**
   * @dev Returns the current bridge operator list.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is bridge operator or not.
   */
  function isBridgeOperator(address _addr) external view returns (bool);

  /**
   * @dev Returns total numbers of the bridge operators.
   */
  function totalBridgeOperators() external view returns (uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                QUERY FUNCTION ABOUT JAILING AND DEPRECATED REWARDS                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) during the current period.
   */
  function jailed(address) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail and the number of block and epoch that he still is in the jail.
   */
  function jailedTimeLeft(address _addr)
    external
    view
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    );

  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) at a specific block.
   */
  function jailedAtBlock(address _addr, uint256 _blockNum) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail at a specific block and the number of block and epoch that he still is in the jail.
   */
  function jailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    external
    view
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    );

  /**
   * @dev Returns whether the validators are put in jail (cannot join the set of validators) during the current period.
   */
  function bulkJailed(address[] memory) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the block producers are deprecated during the current period.
   */
  function miningRewardDeprecated(address[] memory _blockProducers) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the block producers are deprecated during a specific period.
   */
  function miningRewardDeprecatedAtPeriod(address[] memory _blockProducers, uint256 _period)
    external
    view
    returns (bool[] memory);
}
