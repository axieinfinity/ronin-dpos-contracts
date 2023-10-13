// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum ContractKey {
  GovernanceAdmin,
  RoninValidatorSet,
  BridgeTracking,
  RoninGatewayV3,
  SlashIndicator,
  Staking,
  Profile,
  MockPrecompile,
  NotifiedMigrator,
  MainchainGatewayV3,
  FastFinalityTracking,
  RoninTrustedOrganization,
  RoninValidatorSetTimedMigrator,
  StakingVesting,
  BridgeReward,
  BridgeSlash,
  RoninBridgeManager
}

abstract contract ContractConfig {
  mapping(ContractKey contractIdx => string contractName) internal _contractNameMap;
  mapping(uint256 chainId => mapping(string name => address addr)) internal _contractAddrMap;

  constructor() payable {
    // setup contract name
    _contractNameMap[ContractKey.GovernanceAdmin] = "GovernanceAdmin";
    _contractNameMap[ContractKey.RoninValidatorSet] = "RoninValidatorSet";
    _contractNameMap[ContractKey.Staking] = "Staking";
    _contractNameMap[ContractKey.StakingVesting] = "StakingVesting";
    _contractNameMap[ContractKey.NotifiedMigrator] = "NotifiedMigrator";
    _contractNameMap[ContractKey.RoninTrustedOrganization] = "RoninTrustedOrganization";
    _contractNameMap[ContractKey.SlashIndicator] = "SlashIndicator";
    _contractNameMap[ContractKey.RoninValidatorSetTimedMigrator] = "RoninValidatorSetTimedMigrator";
    _contractNameMap[ContractKey.MockPrecompile] = "MockPrecompile";
    _contractNameMap[ContractKey.FastFinalityTracking] = "FastFinalityTracking";
    _contractNameMap[ContractKey.Profile] = "Profile";

    _contractNameMap[ContractKey.MainchainGatewayV3] = "MainchainGatewayV3";
    _contractNameMap[ContractKey.RoninGatewayV3] = "RoninGatewayV3";
    _contractNameMap[ContractKey.BridgeTracking] = "BridgeTracking";
    _contractNameMap[ContractKey.BridgeReward] = "BridgeReward";
    _contractNameMap[ContractKey.BridgeSlash] = "BridgeSlash";
    _contractNameMap[ContractKey.RoninBridgeManager] = "RoninBridgeManager";
    // _contractNameMap[ContractKey.RONRegistrarController] = "RONRegistrarController";
  }

  function getContractName(ContractKey contractKey) public view returns (string memory name) {
    name = _contractNameMap[contractKey];
    require(bytes(name).length != 0, "Contract Key not found");
  }

  function getContractFileName(ContractKey contractKey) public view returns (string memory filename) {
    string memory contractName = getContractName(contractKey);
    filename = string.concat(contractName, ".sol:", contractName);
  }

  function getAddressFromCurrentNetwork(ContractKey contractKey) public view returns (address payable) {
    string memory contractName = _contractNameMap[contractKey];
    require(bytes(contractName).length != 0, "Contract Key not found");
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByString(string memory contractName) public view returns (address payable) {
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByRawData(uint256 chainId, string memory contractName) public view returns (address payable addr) {
    addr = payable(_contractAddrMap[chainId][contractName]);
    require(addr != address(0), string.concat("address not found: ", contractName));
  }
}
