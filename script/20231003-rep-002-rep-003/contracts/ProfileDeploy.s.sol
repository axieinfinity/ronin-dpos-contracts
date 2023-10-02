// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";

contract ProfileDeploy is BaseDeploy {
  function _defaultArguments() internal view override returns (bytes memory args) {
    args = abi.encodeCall(Profile.initialize, _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet));
  }

  function run() public virtual trySetUp returns (Profile) {
    return Profile(_deployProxy(ContractKey.Profile, arguments()));
  }
}
