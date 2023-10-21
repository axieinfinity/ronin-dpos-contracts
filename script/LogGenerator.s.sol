// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { GeneralConfig } from "./GeneralConfig.s.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";

contract LogGenerator {
  using Strings for *;
  using StdStyle for *;
  using stdJson for string;
  using JSONParserLib for *;

  Vm private immutable _vm;
  GeneralConfig private immutable _config;

  constructor(Vm vm, GeneralConfig config) {
    _vm = vm;
    _config = config;
  }

  function generateDeploymentArtifact(
    address deployer,
    address contractAddr,
    string memory contractName,
    string memory fileName,
    bytes memory args,
    uint256 nonce
  ) external {
    console2.log(
      string.concat(fileName, " deployed at: ", contractAddr.toHexString()).green(),
      string.concat("(nonce: ", nonce.toString(), ")")
    );
    if (!_config.getRuntimeConfig().log) {
      console2.log("Skipping artifact generation for:", fileName.yellow());
      return;
    }

    // skip writing artifact if network is localhost
    // if (_network == Network.LocalHost) return;
    string memory dirPath = _config.getDeploymentDirectory(_config.getCurrentNetwork());
    string memory filePath = string.concat(dirPath, fileName, ".json");

    string memory json;
    uint256 numDeployments = 1;

    if (_vm.exists(filePath)) {
      string memory existedJson = _vm.readFile(filePath);
      if (_vm.keyExists(existedJson, ".numDeployments")) {
        numDeployments = _vm.parseJsonUint(_vm.readFile(filePath), ".numDeployments");
        numDeployments += 1;
      }
    }

    json.serialize("nonce", nonce);
    json.serialize("args", args);
    json.serialize("chainId", block.chainid);
    json.serialize("deployer", deployer);
    json.serialize("address", contractAddr);
    json.serialize("timestamp", block.timestamp);
    json.serialize("contractName", contractName);
    json.serialize("numDeployments", numDeployments);
    json.serialize("blockNumber", block.number);
    json.serialize("isFoundry", true);

    string memory artifactPath = string.concat("./out/", contractName, ".sol/", contractName, ".json");
    string memory artifact = _vm.readFile(artifactPath);
    JSONParserLib.Item memory item = artifact.parse();

    json.serialize("bytecode", item.at('"bytecode"').at('"object"').value());
    json.serialize("deployedBytecode", item.at('"deployedBytecode"').at('"object"').value());
    json.serialize("storageLayout", item.at('"storageLayout"').value());
    json.serialize("userdoc", item.at('"userdoc"').value());
    json.serialize("devdoc", item.at('"devdoc"').value());
    json.serialize("abi", item.at('"abi"').value());
    json = json.serialize("metadata", item.at('"rawMetadata"').value());

    json.write(filePath);
  }
}
