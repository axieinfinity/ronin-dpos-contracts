// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 } from "forge-std/console2.sol";

enum Network {
  Local,
  Goerli,
  EthMainnet,
  RoninMainnet,
  RoninTestnet
}

library ChainId {
  uint256 public constant LOCAL = 31337;
  uint256 public constant ETH_MAINNET = 1;
  uint256 public constant GOERLI = 5;
  uint256 public constant RONIN_MAINNET = 2020;
  uint256 public constant RONIN_TESTNET = 2021;
}

abstract contract NetworkConfig {
  struct NetworkData {
    uint256 forkId;
    uint256 chainId;
    string privateKeyEnvLabel;
    string deploymentDir;
    string chainAlias;
  }

  uint256 private constant NULL_FORK_ID = uint256(keccak256("NULL_FORK_ID"));
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  string public constant LOCAL_ALIAS = "localhost";
  string public constant GOERLI_ALIAS = "goerli";
  string public constant ETH_MAINNET_ALIAS = "ethereum";
  string public constant RONIN_TESTNET_ALIAS = "ronin-testnet";
  string public constant RONIN_MAINNET_ALIAS = "ronin-mainnet";

  string public constant LOCAL_DIR = "local/";
  string public constant GOERLI_DIR = "goerli/";
  string public constant ETH_MAINNET_DIR = "ethereum/";
  string public constant RONIN_TESTNET_DIR = "ronin-testnet/";
  string public constant RONIN_MAINNET_DIR = "ronin-mainnet/";

  string public constant LOCAL_ENV_LABEL = "LOCAL_PK";
  string public constant TESTNET_ENV_LABEL = "TESTNET_PK";
  string public constant MAINNET_ENV_LABEL = "MAINNET_PK";

  mapping(Network networkIdx => NetworkData) internal _networkDataMap;
  mapping(uint256 chainId => Network networkIdx) internal _networkMap;

  constructor() payable {
    _networkMap[ChainId.GOERLI] = Network.Goerli;
    _networkDataMap[Network.Goerli] = NetworkData(
      tryCreateFork(GOERLI_ALIAS, ChainId.GOERLI),
      ChainId.GOERLI,
      TESTNET_ENV_LABEL,
      GOERLI_DIR,
      GOERLI_ALIAS
    );

    _networkMap[ChainId.ETH_MAINNET] = Network.EthMainnet;
    _networkDataMap[Network.EthMainnet] = NetworkData(
      tryCreateFork(ETH_MAINNET_ALIAS, ChainId.ETH_MAINNET),
      ChainId.ETH_MAINNET,
      MAINNET_ENV_LABEL,
      ETH_MAINNET_DIR,
      ETH_MAINNET_ALIAS
    );

    _networkMap[ChainId.LOCAL] = Network.Local;
    _networkDataMap[Network.Local] = NetworkData(
      tryCreateFork(LOCAL_ALIAS, ChainId.LOCAL),
      ChainId.LOCAL,
      LOCAL_ENV_LABEL,
      LOCAL_DIR,
      LOCAL_ALIAS
    );

    _networkMap[ChainId.RONIN_TESTNET] = Network.RoninTestnet;
    _networkDataMap[Network.RoninTestnet] = NetworkData(
      tryCreateFork(RONIN_TESTNET_ALIAS, ChainId.RONIN_TESTNET),
      ChainId.RONIN_TESTNET,
      TESTNET_ENV_LABEL,
      RONIN_TESTNET_DIR,
      RONIN_TESTNET_ALIAS
    );

    _networkMap[ChainId.RONIN_MAINNET] = Network.RoninMainnet;
    _networkDataMap[Network.RoninMainnet] = NetworkData(
      tryCreateFork(RONIN_MAINNET_ALIAS, ChainId.RONIN_MAINNET),
      ChainId.RONIN_MAINNET,
      MAINNET_ENV_LABEL,
      RONIN_MAINNET_DIR,
      RONIN_MAINNET_ALIAS
    );
  }

  function tryCreateFork(string memory chainAlias, uint256 chainId) public returns (uint256) {
    try vm.createFork(vm.rpcUrl(chainAlias)) returns (uint256 forkId) {
      console2.log(StdStyle.blue(string.concat("NetworkConfig: ", chainAlias, " fork created with forkId:")), forkId);
      return forkId;
    } catch {
      console2.log(StdStyle.red("NetworkConfig: Cannot create fork with url:"), vm.rpcUrl(chainAlias));
      return NULL_FORK_ID;
    }
  }

  function switchTo(Network network) public {
    uint256 forkId = _networkDataMap[network].forkId;
    require(forkId != NULL_FORK_ID, "Network Config: Unexists fork!");
    vm.selectFork(forkId);
    require(_networkDataMap[network].chainId == block.chainid, "NetworkConfig: Switch chain failed");
  }

  function getPrivateKeyEnvLabelFromCurrentNetwork() public view returns (string memory privatekeyEnvLabel) {
    privatekeyEnvLabel = getPrivateKeyEnvLabel(getCurrentNetwork());
  }

  function getPrivateKeyEnvLabel(Network network) public view returns (string memory privateKeyEnvLabel) {
    privateKeyEnvLabel = _networkDataMap[network].privateKeyEnvLabel;
    require(bytes(privateKeyEnvLabel).length != 0, "Network Config: ENV label not found");
  }

  function getCurrentNetwork() public view returns (Network network) {
    network = _networkMap[block.chainid];
  }

  function getNetworkByChainId(uint256 chainId) public view returns (Network network) {
    network = _networkMap[chainId];
  }
}
