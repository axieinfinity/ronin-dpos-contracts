// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IScript, BaseScript } from "./BaseScript.s.sol";
import { LogGenerator } from "./LogGenerator.s.sol";
import "./GeneralConfig.s.sol";
import { IDeployScript } from "./interfaces/IDeployScript.sol";

abstract contract BaseDeploy is BaseScript {
  using StdStyle for string;

  bytes public constant EMPTY_ARGS = "";
  bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  bool internal _alreadySetUp;
  bytes internal _overridenArgs;
  LogGenerator internal _logger;
  mapping(ContractKey contractKey => IDeployScript deployScript) internal _deployScript;

  modifier trySetUp() {
    if (!_alreadySetUp) {
      setUp();
      _alreadySetUp = true;
    }
    _;
  }

  function setUp() public virtual override {
    vm.pauseGasMetering();
    _alreadySetUp = true;
    super.setUp();
    _logger = new LogGenerator(vm, _config);
    _injectDependencies();
  }

  function _injectDependencies() internal virtual {}

  function _setDependencyDeployScript(ContractKey contractKey, IScript deployScript) internal {
    _deployScript[contractKey] = IDeployScript(address(deployScript));
  }

  function loadContractOrDeploy(ContractKey contractKey) public returns (address payable contractAddr) {
    string memory contractName = _config.getContractName(contractKey);
    try _config.getAddressFromCurrentNetwork(contractKey) returns (address payable addr) {
      contractAddr = addr;
    } catch {
      console2.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractKey].run();
    }
  }

  function setArgs(bytes memory args) public returns (IDeployScript) {
    _overridenArgs = args;
    return IDeployScript(address(this));
  }

  function arguments() public returns (bytes memory args) {
    args = _overridenArgs.length == 0 ? _defaultArguments() : _overridenArgs;
  }

  function _defaultArguments() internal virtual returns (bytes memory args) {}

  function _deployImmutable(ContractKey contractKey, bytes memory args) internal returns (address payable deployed) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);
    uint256 nonce;
    (deployed, nonce) = _deployRaw(contractFilename, args);
    vm.label(deployed, contractName);

    _config.setAddress(_network, contractKey, deployed);
    _logger.generateDeploymentArtifact(_sender, deployed, contractName, contractName, args, nonce);
  }

  function _upgradeProxy(ContractKey contractKey, bytes memory args) internal returns (address payable proxy) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);

    uint256 logicNonce;
    address logic;
    (logic, logicNonce) = _deployRaw(contractFilename, EMPTY_ARGS);

    proxy = _config.getAddressFromCurrentNetwork(contractKey);
    address proxyAdmin = _getProxyAdmin(proxy);
    _upgradeRaw(proxyAdmin, proxy, logic, args);

    _logger.generateDeploymentArtifact(
      _sender,
      logic,
      contractName,
      string.concat(contractName, "Logic"),
      EMPTY_ARGS,
      logicNonce
    );
  }

  function _getProxyAdmin(address proxy) internal view returns (address payable) {
    return payable(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
  }

  function _getProxyImplementation(address proxy) internal view returns (address payable) {
    return payable(address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))));
  }

  function _deployLogic(ContractKey contractKey, bytes memory args) internal returns (address payable logic) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);

    uint256 logicNonce;
    (logic, logicNonce) = _deployRaw(contractFilename, args);
    _logger.generateDeploymentArtifact(
      _sender,
      logic,
      contractName,
      string.concat(contractName, "Logic"),
      EMPTY_ARGS,
      logicNonce
    );
  }

  function _deployProxy(ContractKey contractKey, bytes memory args) internal returns (address payable deployed) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);
    (address logic, uint256 logicNonce) = _deployRaw(contractFilename, EMPTY_ARGS);

    uint256 proxyNonce;
    (deployed, proxyNonce) = _deployRaw(
      "TransparentUpgradeableProxyV2.sol:TransparentUpgradeableProxyV2",
      abi.encode(logic, _config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin), args)
    );
    vm.label(deployed, contractName);

    _config.setAddress(_network, contractKey, deployed);
    _logger.generateDeploymentArtifact(
      _sender,
      logic,
      contractName,
      string.concat(contractName, "Logic"),
      EMPTY_ARGS,
      logicNonce
    );
    _logger.generateDeploymentArtifact(
      _sender,
      deployed,
      "TransparentUpgradeableProxyV2",
      string.concat(contractName, "Proxy"),
      args,
      proxyNonce
    );
  }

  function _deployRaw(
    string memory filename,
    bytes memory args
  ) internal returns (address payable deployed, uint256 nonce) {
    nonce = vm.getNonce(_sender);
    address expectedAddr = computeCreateAddress(_sender, nonce);

    vm.resumeGasMetering();
    vm.broadcast(_sender);
    deployed = payable(deployCode(filename, args));
    vm.pauseGasMetering();

    require(deployed == expectedAddr, "deployed != expectedAddr");
  }

  function _upgradeRaw(
    address proxyAdmin,
    address payable proxy,
    address logic,
    bytes memory args
  ) internal returns (address payable) {
    vm.broadcast(address(proxyAdmin));
    vm.resumeGasMetering();
    if (args.length == 0) TransparentUpgradeableProxy(proxy).upgradeTo(logic);
    else TransparentUpgradeableProxy(proxy).upgradeToAndCall(logic, args);
    vm.pauseGasMetering();

    return proxy;
  }
}
