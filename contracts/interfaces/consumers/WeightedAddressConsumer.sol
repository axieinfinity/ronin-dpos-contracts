// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface WeightedAddressConsumer {
  struct WeightedAddress {
    address addr;
    uint256 weight;
  }
}
