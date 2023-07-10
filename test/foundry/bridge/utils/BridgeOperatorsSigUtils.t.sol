// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BridgeOperatorsBallot } from "@ronin/contracts/libraries/BridgeOperatorsBallot.sol";

contract BridgeOperatorsSigUtils {
  using BridgeOperatorsBallot for *;

  bytes32 public constant PERMIT_TYPEHASH = BridgeOperatorsBallot.BRIDGE_OPERATORS_BALLOT_TYPEHASH;
  bytes32 internal immutable DOMAIN_SEPARATOR;

  constructor(bytes32 _DOMAIN_SEPARATOR) {
    DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
  }

  // computes the hash of a permit
  function getStructHash(BridgeOperatorsBallot.BridgeOperatorSet memory _permit) internal pure returns (bytes32) {
    return BridgeOperatorsBallot.hash(_permit);
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(BridgeOperatorsBallot.BridgeOperatorSet memory _permit) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
  }
}
