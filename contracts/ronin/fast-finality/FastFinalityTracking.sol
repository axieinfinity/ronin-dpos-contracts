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

  modifier onlyCoinbase() {
    if (msg.sender != block.coinbase) revert ErrCallerMustBeCoinbase();
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function recordFinality(address[] calldata voters) external override oncePerBlock onlyCoinbase {
    uint256 currentEpoch = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).epochOf(block.number);

    for (uint i; i < voters.length; ) {
      unchecked {
        ++_tracker[currentEpoch][voters[i]];
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityVoteCounts(
    uint256 epoch,
    address[] calldata addrs
  ) external view override returns (uint256[] memory voteCounts) {
    uint256 length = addrs.length;
    voteCounts = new uint256[](length);
    for (uint i; i < length; ) {
      voteCounts[i] = _tracker[epoch][addrs[i]];
      unchecked {
        ++i;
      }
    }
  }
}
