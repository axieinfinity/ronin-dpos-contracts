// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IFastFinalityTracking } from "../..//interfaces/IFastFinalityTracking.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../utils/CommonErrors.sol";

contract FastFinalityTracking is IFastFinalityTracking, Initializable, HasContracts {
  /// @dev Mapping from epoch number => consensus address => number of QC vote
  mapping(uint256 => mapping(address => uint256)) internal _tracker;
  /// @dev The latest block that tracked the QC vote
  uint256 internal _latestTrackingBlock;

  modifier oncePerBlock() {
    if (block.number <= _latestTrackingBlock) {
      revert ErrOncePerBlock();
    }

    _latestTrackingBlock = block.number;
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _validatorContract
  )
    external
    // uint256 _startedAtBlock
    initializer
  {
    _setContract(ContractType.VALIDATOR, _validatorContract);
    // startedAtBlock = _startedAtBlock;
  }

  function recordFinality(address[] calldata voters) external override oncePerBlock {
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();

    for (uint i; i < voters.length; ) {
      ++_tracker[currentPeriod][voters[i]];
      unchecked {
        ++i;
      }
    }
  }

  function getManyFinalityVoteCounts(
    uint256 epoch,
    address[] calldata addrs
  ) external view override returns (uint256[] memory voteCounts) {
    for (uint i; i < addrs.length; ) {
      voteCounts[i] = _tracker[epoch][addrs[i]];
      unchecked {
        ++i;
      }
    }
  }
}
