// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";
import { ErrUnauthorizedCall } from "../../../utils/CommonErrors.sol";

contract NotifiedMigrator is ConditionalImplementControl {
  address public immutable NOTIFIER;

  constructor(
    address proxyStorage,
    address prevImpl,
    address newImpl,
    address notifier
  ) payable ConditionalImplementControl(proxyStorage, prevImpl, newImpl) {
    NOTIFIER = notifier;
  }

  /**
   * @dev See {IConditionalImplementControl-selfUpgrade}.
   */
  function selfUpgrade() external override onlyDelegateFromProxyStorage {
    if (msg.sender != NOTIFIER) revert ErrUnauthorizedCall(msg.sig);
    _upgradeTo(NEW_IMPL);
  }
}
