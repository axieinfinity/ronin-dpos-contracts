// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILogic {
  event Received(uint256 version);

  function name() external pure returns (string memory);

  function magicNumber() external view returns (uint256);

  function get() external view returns (uint256);

  function set() external;

  function setAndGet() external returns (uint256);
}

abstract contract MockLogicBase is ILogic {
  uint256 internal _value;

  function magicNumber() public view virtual override returns (uint256) {}

  receive() external payable virtual {
    emit Received(0);
  }

  function get() public view returns (uint256) {
    return _value;
  }

  function set() public override {
    _value = magicNumber();
  }

  function setAndGet() public returns (uint256) {
    set();
    return get();
  }
}

contract MockLogicV1 is MockLogicBase {
  receive() external payable override {
    emit Received(1);
  }

  function name() external pure returns (string memory) {
    return "LogicV1";
  }

  function magicNumber() public pure override returns (uint256) {
    return 1;
  }
}

contract MockLogicV2 is MockLogicBase {
  receive() external payable override {
    emit Received(2);
  }

  function name() external pure returns (string memory) {
    return "LogicV2";
  }

  function magicNumber() public pure override returns (uint256) {
    return 2;
  }
}
