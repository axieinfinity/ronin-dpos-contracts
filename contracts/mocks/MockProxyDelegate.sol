// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library ErrorHandler {
  function handleRevert(bool status, bytes memory returnOrRevertData) internal pure {
    assembly {
      if iszero(status) {
        let revertLength := mload(returnOrRevertData)
        if iszero(iszero(revertLength)) {
          // Start of revert data bytes. The 0x20 offset is always the same.
          revert(add(returnOrRevertData, 0x20), revertLength)
        }

        /// @dev equivalent to revert ExecutionFailed()
        mstore(0x00, 0xacfdb444)
        revert(0x1c, 0x04)
      }
    }
  }
}

contract MockProxyDelegate {
  error ExecutionFailed();

  using ErrorHandler for bool;

  /// @dev value is equal to keccak256("MockProxyDelegate.slot") - 1
  bytes32 public constant SLOT = 0xd7e37bb02f38a001dc6dc288698347e84408fb1c25d8015413a6203a79da346f;

  constructor(
    address target_,
    address admin_,
    address implement_
  ) {
    assembly {
      sstore(SLOT, target_)
      /// @dev value is equal to keccak256("eip1967.proxy.admin") - 1
      sstore(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, admin_)
      /// @dev value is equal to keccak256("eip1967.proxy.implementation") - 1
      sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, implement_)
    }
  }

  function slashDoubleSign(
    address,
    bytes calldata,
    bytes calldata
  ) external {
    address target;
    assembly {
      target := sload(SLOT)
    }
    (bool success, bytes memory returnOrRevertData) = target.delegatecall(
      abi.encodeWithSelector(
        /// @dev value is equal to bytes4(keccak256(functionDelegate(bytes)))
        0x4bb5274a,
        msg.data
      )
    );
    success.handleRevert(returnOrRevertData);
  }
}
