// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/IJailingInfo.sol";

abstract contract JailingStorage is IJailingInfo {
  /// @dev Mapping from candidate id => period number => block producer has no pending reward.
  mapping(address => mapping(uint256 => bool)) internal _miningRewardDeprecatedAtPeriod;
  /// @dev Mapping from candidate id => period number => whether the block producer get cut off reward, due to bailout.
  mapping(address => mapping(uint256 => bool)) internal _miningRewardBailoutCutOffAtPeriod;
  /// @dev Mapping from candidate id => period number => block operator has no pending reward.
  mapping(address => mapping(uint256 => bool)) internal ______deprecatedBridgeRewardDeprecatedAtPeriod;

  /// @dev Mapping from candidate id => the last block that the block producer is jailed.
  mapping(address => uint256) internal _blockProducerJailedBlock;
  /// @dev Mapping from candidate id => the last timestamp that the bridge operator is jailed.
  mapping(address => uint256) internal _emergencyExitJailedTimestamp;
  /// @dev Mapping from candidate id => the last block that the block producer cannot bailout.
  mapping(address => uint256) internal _cannotBailoutUntilBlock;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[48] private ______gap;

  /**
   * @inheritdoc IJailingInfo
   */
  function checkJailed(TConsensus consensus) external view override returns (bool) {
    address candidateId = __css2cid(consensus);
    return _isJailedAtBlockById(candidateId, block.number);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkJailedAtBlock(TConsensus addr, uint256 blockNum) external view override returns (bool) {
    address candidateId = __css2cid(addr);
    return _isJailedAtBlockById(candidateId, blockNum);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function getJailedTimeLeft(
    TConsensus consensus
  ) external view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {
    return _getJailedTimeLeftAtBlockById(__css2cid(consensus), block.number);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function getJailedTimeLeftAtBlock(
    TConsensus consensus,
    uint256 _blockNum
  ) external view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {
    return _getJailedTimeLeftAtBlockById(__css2cid(consensus), _blockNum);
  }

  function _getJailedTimeLeftAtBlockById(
    address candidateId,
    uint256 blockNum
  ) internal view returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {
    uint256 jailedBlock = _blockProducerJailedBlock[candidateId];
    if (jailedBlock < blockNum) {
      return (false, 0, 0);
    }

    isJailed_ = true;
    blockLeft_ = jailedBlock - blockNum + 1;
    epochLeft_ = epochOf(jailedBlock) - epochOf(blockNum) + 1;
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkManyJailed(TConsensus[] calldata consensusList) external view override returns (bool[] memory) {
    return _checkManyJailedById(__css2cidBatch(consensusList));
  }

  function checkManyJailedById(address[] calldata candidateIds) external view override returns (bool[] memory) {
    return _checkManyJailedById(candidateIds);
  }

  function _checkManyJailedById(address[] memory candidateIds) internal view returns (bool[] memory result) {
    result = new bool[](candidateIds.length);
    for (uint256 i; i < candidateIds.length; ) {
      result[i] = _isJailedById(candidateIds[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkMiningRewardDeprecated(TConsensus consensus) external view override returns (bool) {
    uint256 period = currentPeriod();
    return _miningRewardDeprecatedById(__css2cid(consensus), period);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkMiningRewardDeprecatedAtPeriod(
    TConsensus consensus,
    uint256 period
  ) external view override returns (bool) {
    return _miningRewardDeprecatedById(__css2cid(consensus), period);
  }

  /**
   * @dev See `ITimingInfo-epochOf`
   */
  function epochOf(uint256 _block) public view virtual returns (uint256);

  /**
   * @dev See `ITimingInfo-currentPeriod`
   */
  function currentPeriod() public view virtual returns (uint256);

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) during the current period.
   */
  function _isJailedById(address validatorId) internal view returns (bool) {
    return _isJailedAtBlockById(validatorId, block.number);
  }

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) at a specific block.
   */
  function _isJailedAtBlockById(address validatorId, uint256 blockNum) internal view returns (bool) {
    return blockNum <= _blockProducerJailedBlock[validatorId];
  }

  /**
   * @dev Returns whether the block producer has no pending reward in that period.
   */
  function _miningRewardDeprecatedById(address validatorId, uint256 period) internal view returns (bool) {
    return _miningRewardDeprecatedAtPeriod[validatorId][period];
  }

  /// @dev See {RoninValidatorSet-__css2cid}
  function __css2cid(TConsensus consensusAddr) internal view virtual returns (address);

  /// @dev See {RoninValidatorSet-__css2cidBatch}
  function __css2cidBatch(TConsensus[] memory consensusAddrs) internal view virtual returns (address[] memory);
}
