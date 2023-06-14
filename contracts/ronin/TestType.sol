// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

type Custom is address;

contract X {
  Custom[] a;

  function foo(Custom x) public {
    a.push(x);
  }
}
