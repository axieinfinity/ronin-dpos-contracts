// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/**
 * @dev This library implement checking flag of a enumerated value.
 * The originated idea is inherited from [Enum.HashFlag(Enum)](https://learn.microsoft.com/en-us/dotnet/api/system.enum.hasflag?view=net-6.0) method of C#.
 */
library EnumFlags {
  enum ValidatorFlag {
    None, // bit(00)
    BlockProducer, // bit(01)
    BridgeOperator, // bit(10)
    Both // bit(11)
  }

  /**
   * @dev Checks if `_value` has `flag`.
   */
  function hasFlag(ValidatorFlag _value, ValidatorFlag _flag) internal pure returns (bool) {
    return (uint8(_value) & uint8(_flag)) != 0;
  }

  /**
   * @dev Calculate new value of `_value` after adding `flag`.
   */
  function addFlag(ValidatorFlag _value, ValidatorFlag _flag) internal pure returns (ValidatorFlag) {
    return ValidatorFlag(uint8(_value) | uint8(_flag));
  }

  /**
   * @dev Calculate new value of `_value` after remove `flag`.
   */
  function removeFlag(ValidatorFlag _value, ValidatorFlag _flag) internal pure returns (ValidatorFlag) {
    return ValidatorFlag(uint8(_value) & ~uint8(_flag));
  }
}
