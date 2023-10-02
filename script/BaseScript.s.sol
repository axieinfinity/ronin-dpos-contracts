// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Script, console2 } from "forge-std/Script.sol";
import "./GeneralConfig.s.sol";
import { IScript } from "./interfaces/IScript.sol";
import { IDeployScript } from "./interfaces/IDeployScript.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";

abstract contract BaseScript is Script, IScript {
  using LibString for string;
  using StdStyle for string;
  using ErrorHandler for bool;

  string public constant TREZOR_PREFIX = "trezor://";
  bytes32 public constant GENERAL_CONFIG_SALT = keccak256(bytes(type(GeneralConfig).name));

  address internal _sender;
  Network internal _network;
  GeneralConfig internal _config;

  modifier onMainnet() {
    _network = Network.RoninMainnet;
    _;
  }

  modifier onTestnet() {
    _network = Network.RoninTestnet;
    _;
  }

  modifier onLocalHost() {
    _network = Network.Local;
    _;
  }

  function setUp() public virtual {
    // allow diferrent deploy scripts to share same config storage
    // predict general config address
    address cfgAddr = computeCreate2Address(
      GENERAL_CONFIG_SALT,
      hashInitCode(abi.encodePacked(type(GeneralConfig).creationCode), abi.encode(vm))
    );
    vm.allowCheatcodes(cfgAddr);
    // skip if general config already deployed
    if (cfgAddr.code.length == 0) {
      vm.prank(CREATE2_FACTORY);
      new GeneralConfig{ salt: GENERAL_CONFIG_SALT }(vm);
    }

    _config = GeneralConfig(payable(cfgAddr));
    _network = _config.getCurrentNetwork();
  }

  function run(string calldata command) external {
    RuntimeConfig.Options memory options = _parseRuntimeConfig(command);
    _config.setRuntimeConfig(options);

    if (options.trezor) {
      string memory str = vm.envString(_config.DEPLOYER_ENV_LABEL());
      _sender = vm.parseAddress(str.replace(TREZOR_PREFIX, ""));
      console2.log(StdStyle.blue("Trezor Account:"), _sender);
    } else {
      uint256 pk = vm.envUint(_config.getPrivateKeyEnvLabel(_network));
      _sender = vm.rememberKey(pk);
      console2.log(StdStyle.blue(".ENV Account:"), _sender);
    }
    vm.label(_sender, "sender");

    (bool success, bytes memory returnOrRevertData) = address(this).delegatecall(abi.encodeCall(IDeployScript.run, ()));
    success.handleRevert(IDeployScript.run.selector, returnOrRevertData);
  }

  function _parseRuntimeConfig(string memory command) private pure returns (RuntimeConfig.Options memory options) {
    if (bytes(command).length != 0) {
      string[] memory args = command.split(" ");
      uint256 length = args.length;

      for (uint256 i; i < length; ) {
        if (args[i].eq("log")) options.log = true;
        else if (args[i].eq("trezor")) options.trezor = true;
        else revert(string.concat("Unsupported command: ", args[i]).red());

        unchecked {
          ++i;
        }
      }
    }
  }
}
