// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Proposal.sol";

library GlobalProposal {
  /**
   * @dev Error thrown when attempting to interact with an unsupported target.
   */
  error ErrUnsupportedTarget();

  enum TargetOption {
    RoninTrustedOrganizationContract,
    GatewayContract
  }

  struct GlobalProposalDetail {
    // Nonce to make sure proposals are executed in order
    uint256 nonce;
    uint256 expiryTimestamp;
    TargetOption[] targetOptions;
    uint256[] values;
    bytes[] calldatas;
    uint256[] gasAmounts;
  }

  // keccak256("GlobalProposalDetail(uint256 nonce,uint256 expiryTimestamp,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 public constant TYPE_HASH = 0x1463f426c05aff2c1a7a0957a71c9898bc8b47142540538e79ee25ee91141350;

  /**
   * @dev Returns struct hash of the proposal.
   */
  function hash(GlobalProposalDetail memory _proposal) internal pure returns (bytes32 digest) {
    uint256[] memory _values = _proposal.values;
    TargetOption[] memory _targets = _proposal.targetOptions;
    bytes32[] memory _calldataHashList = new bytes32[](_proposal.calldatas.length);
    uint256[] memory _gasAmounts = _proposal.gasAmounts;

    for (uint256 _i; _i < _calldataHashList.length; ) {
      _calldataHashList[_i] = keccak256(_proposal.calldatas[_i]);

      unchecked {
        ++_i;
      }
    }

    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, TYPE_HASH)
      mstore(add(freeMemPtr, 0x20), mload(_proposal))
      mstore(add(freeMemPtr, 0x40), mload(add(_proposal, 0x20)))
      // targetsHash
      let arrayHashed := keccak256(add(_targets, 32), mul(mload(_targets), 32))
      mstore(add(freeMemPtr, 0x60), arrayHashed)
      // _valuesHash
      arrayHashed := keccak256(add(_values, 32), mul(mload(_values), 32))
      mstore(add(freeMemPtr, 0x80), arrayHashed)
      // _calldatasHash
      arrayHashed := keccak256(add(_calldataHashList, 32), mul(mload(_calldataHashList), 32))
      mstore(add(freeMemPtr, 0xa0), arrayHashed)
      // _gasAmountsHash
      arrayHashed := keccak256(add(_gasAmounts, 32), mul(mload(_gasAmounts), 32))
      mstore(add(freeMemPtr, 0xc0), arrayHashed)
      digest := keccak256(freeMemPtr, 0xe0)
    }
  }

  /**
   * @dev Converts into the normal proposal.
   */
  function into_proposal_detail(
    GlobalProposalDetail memory _proposal,
    address _roninTrustedOrganizationContract,
    address _gatewayContract
  ) internal pure returns (Proposal.ProposalDetail memory _detail) {
    _detail.nonce = _proposal.nonce;
    _detail.expiryTimestamp = _proposal.expiryTimestamp;
    _detail.chainId = 0;
    _detail.targets = new address[](_proposal.targetOptions.length);
    _detail.values = _proposal.values;
    _detail.calldatas = _proposal.calldatas;
    _detail.gasAmounts = _proposal.gasAmounts;

    for (uint256 _i; _i < _proposal.targetOptions.length; ) {
      if (_proposal.targetOptions[_i] == TargetOption.GatewayContract) {
        _detail.targets[_i] = _gatewayContract;
      } else if (_proposal.targetOptions[_i] == TargetOption.RoninTrustedOrganizationContract) {
        _detail.targets[_i] = _roninTrustedOrganizationContract;
      } else revert ErrUnsupportedTarget();

      unchecked {
        ++_i;
      }
    }
  }
}
