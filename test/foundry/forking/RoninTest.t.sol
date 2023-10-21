// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { Base_Test } from "@ronin/test/Base.t.sol";

import { ITransparentUpgradeableProxyDeployer, TransparentUpgradeableProxyV3 } from "./extensions/TransparentUpgradeableProxyV3.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";

import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";

import "./utils/Consts.sol";

abstract contract RoninTest is Base_Test, ITransparentUpgradeableProxyDeployer {
  error ErrDeployFailed();

  struct TransparentUpgradeableProxyParams {
    address admin;
    address implement;
    bytes data;
  }

  uint256 internal constant DEFAULT_BALANCE = 1_000 ether;
  uint256 private constant ADMIN_PK = uint256(keccak256(abi.encode("ADMIN")));
  uint256 internal constant INITIAL_SEED = uint256(keccak256(abi.encode("INITIAL_SEED")));

  string internal constant PROXY_PREFIX = "Proxy_";
  string internal constant LOGIC_PREFIX = "Logic_";

  address internal _defaultAdmin;
  TransparentUpgradeableProxyParams private _params;

  modifier whenDeployProxy(
    address proxyAdmin,
    address impl,
    bytes memory data
  ) {
    _params = TransparentUpgradeableProxyParams({ admin: proxyAdmin, implement: impl, data: data });
    _;
    delete _params;
  }

  modifier onWhichFork(uint256 forkId) virtual {
    uint256 currentFork = vm.activeFork();
    vm.selectFork(forkId);
    _;
    vm.selectFork(currentFork);
  }

  modifier fromWho(address who) virtual {
    vm.startPrank(who, who);
    _;
    vm.stopPrank();
  }

  function paramAdmin() external view returns (address) {
    return _params.admin;
  }

  function paramLogic() external view returns (address) {
    return _params.implement;
  }

  function paramExtraData() external view returns (bytes memory) {
    return _params.data;
  }

  function setUp() external {
    vm.label(address(RONIN_GOVERNANCE_ADMIN_CONTRACT), type(RoninGovernanceAdmin).name);
    vm.label(address(RONIN_GATEWAY_CONTRACT), _getProxyLabel(type(RoninGatewayV3).name));
    vm.label(address(ETH_GATEWAY_CONTRACT), _getProxyLabel(type(MainchainGatewayV3).name));
    vm.label(address(RONIN_BRIDGE_TRACKING_CONTRACT), _getProxyLabel(type(BridgeTracking).name));
    vm.label(address(RONIN_VALIDATOR_SET_CONTRACT), _getProxyLabel(type(RoninValidatorSet).name));

    _defaultAdmin = _createPersistentAccount(ADMIN_PK, DEFAULT_BALANCE);
    vm.label(_defaultAdmin, "DEFAULT_ADMIN");

    _createFork();
    _setUp();
    _label();
  }

  function _createFork() internal virtual {}

  function _setUp() internal virtual;

  function _label() internal virtual {}

  function deployImmutable(
    string memory contractName,
    bytes memory creationCode,
    bytes memory params,
    uint256 value
  ) public returns (address impl) {
    bytes32 salt = _computeSalt(contractName);
    bytes memory bytecode = _computeByteCode(creationCode, params);

    bytes4 deployFailed = ErrDeployFailed.selector;
    assembly ("memory-safe") {
      impl := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
      if iszero(impl) {
        mstore(0x00, deployFailed)
        revert(0x1c, 0x04)
      }
    }

    vm.label(impl, contractName);
  }

  function _computeByteCode(
    bytes memory creationCode,
    bytes memory params
  ) internal pure returns (bytes memory bytecode) {
    bytecode = params.length != 0 ? abi.encodePacked(creationCode, params) : creationCode;
  }

  function _computeSalt(string memory contractName) internal pure returns (bytes32 salt) {
    salt = keccak256(bytes(contractName));
  }

  function deployProxy(
    string memory contractName,
    bytes memory logicCode,
    address proxyAdmin,
    uint256 value,
    bytes memory callData
  )
    public
    whenDeployProxy(
      proxyAdmin,
      _computeAddress({ contractName: _getLogicLabel(contractName), creationCode: logicCode, params: "" }),
      callData
    )
    returns (TransparentUpgradeableProxyV2 proxy, address impl)
  {
    impl = deployImmutable({
      contractName: _getLogicLabel(contractName),
      creationCode: logicCode,
      params: "",
      value: 0
    });

    string memory proxyContractName = _getProxyLabel(contractName);
    proxy = TransparentUpgradeableProxyV2(
      payable(address(new TransparentUpgradeableProxyV3{ salt: _computeSalt(proxyContractName), value: value }()))
    );
    vm.label(address(proxy), proxyContractName);
  }

  function upgradeToAndCall(
    TransparentUpgradeableProxyV2 proxy,
    string memory contractName,
    bytes memory logicCode,
    bytes memory callData
  ) public returns (address impl, address proxyAdmin) {
    impl = deployImmutable(_getLogicLabel(contractName), logicCode, "", 0);
    proxyAdmin = _getProxyAdmin(proxy);
    vm.prank(proxyAdmin, proxyAdmin);
    proxy.upgradeToAndCall(impl, callData);
  }

  function upgradeTo(
    TransparentUpgradeableProxyV2 proxy,
    string memory contractName,
    bytes memory logicCode
  ) public returns (address impl, address proxyAdmin) {
    impl = deployImmutable(_getLogicLabel(contractName), logicCode, "", 0);
    proxyAdmin = _getProxyAdmin(proxy);
    vm.prank(proxyAdmin, proxyAdmin);
    proxy.upgradeTo(impl);
  }

  function _join(string memory a, string memory b) internal pure returns (string memory c) {
    c = string(abi.encodePacked(a, b));
  }

  function _computeAddress(
    string memory contractName,
    bytes memory creationCode,
    bytes memory params
  ) internal view returns (address) {
    bytes32 salt = _computeSalt(contractName);
    bytes32 initcodeHash = keccak256(_computeByteCode(creationCode, params));
    return computeCreate2Address(salt, initcodeHash, address(this));
  }

  function _getLogicLabel(string memory contractName) internal pure returns (string memory) {
    return _join(LOGIC_PREFIX, contractName);
  }

  function _getProxyLabel(string memory contractName) internal pure returns (string memory) {
    return _join(PROXY_PREFIX, contractName);
  }

  function _getProxyAdmin(TransparentUpgradeableProxyV2 proxy) internal view returns (address) {
    return address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));
  }

  function _getProxyImplementation(TransparentUpgradeableProxyV2 proxy) internal view returns (address) {
    return address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
  }

  function _getDefaultAdminPrivateKey() internal pure returns (uint256) {
    return boundPrivateKey(ADMIN_PK);
  }

  function _createPersistentAccount(uint256 privateKey, uint256 defaultBalance) internal returns (address addr) {
    addr = vm.addr(privateKey);
    vm.makePersistent(addr);
    if (defaultBalance != 0) {
      vm.deal(addr, defaultBalance);
    }
  }

  function _createPersistentAccount(
    string memory label,
    uint256 defaultBalance
  ) internal returns (Account memory account) {
    account = makeAccount(label);
    vm.makePersistent(account.addr);
    if (defaultBalance != 0) {
      vm.deal(account.addr, defaultBalance);
    }
  }
}
