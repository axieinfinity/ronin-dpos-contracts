// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../RoninTest.t.sol";

import "@ronin/test/bridge/unit/fuzz/utils/BridgeManagerUtils.t.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
// RON
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";

import { Ballot, GlobalProposal, RoninBridgeManager, BridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";

// ETH
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";

contract NewBridgeForkTest is RoninTest, BridgeManagerUtils, SignatureConsumer {
  using Sorting for *;
  using Transfer for Transfer.Receipt;
  using Transfer for Transfer.Request;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /// @dev Emitted when the deposit is requested
  event DepositRequested(bytes32 receiptHash, Transfer.Receipt receipt);

  uint256 internal constant DEFAULT_NUMERATOR = 2;
  uint256 internal constant DEFAULT_DENOMINATOR = 4;
  uint256 internal constant DEFAULT_WEIGHT = 1000;
  uint256 internal constant DEFAULT_REWARD_PER_PERIOD = 1 ether;
  uint256 internal constant DEFAULT_EXPIRY_DURATION = 5 minutes;
  uint256 internal constant DEFAULT_GAS = 500_000;

  // @dev fork height before REP-002 upgrade
  // TODO: must be tested on mainnet
  uint256 internal constant FORK_HEIGHT = 19231486;

  uint256 internal _ethFork;
  uint256 internal _ethChainId;
  uint256 internal _roninFork;
  uint256 internal _ronChainId;
  uint256 internal _nonce;

  uint96[] internal _weights;
  address[] internal _governors;
  address[] internal _operators;

  bytes internal _bridgeOperatorInfo;

  // contracts on RON
  RoninBridgeManager internal _ronBridgeManagerContract;
  TransparentUpgradeableProxyV2 internal _ronBridgeSlashProxy;
  TransparentUpgradeableProxyV2 internal _ronBridgeRewardProxy;

  // contracts on ETH
  MainchainBridgeManager internal _ethBridgeManagerContract;

  function _setUp() internal virtual override {
    (_governors, _operators, _weights) = createBridgeOperatorInfo();

    _setUpOnRON();
    _setUpOnETH();
  }

  function test_Fork_DepositToGateway() external {
    Account memory user = _createPersistentAccount("USER", DEFAULT_BALANCE);

    Transfer.Request memory request = Transfer.Request(
      user.addr,
      address(0),
      Token.Info(Token.Standard.ERC20, 0, 1 ether)
    );
    vm.selectFork(_ethFork);
    address weth = address(MainchainGatewayV3(payable(address(ETH_GATEWAY_CONTRACT))).wrappedNativeToken());
    MappedTokenConsumer.MappedToken memory token = IMainchainGatewayV3(address(ETH_GATEWAY_CONTRACT)).getRoninToken(
      weth
    );

    Transfer.Receipt memory receipt = Transfer.Request(user.addr, weth, request.info).into_deposit_receipt(
      user.addr,
      IMainchainGatewayV3(address(ETH_GATEWAY_CONTRACT)).depositCount(),
      token.tokenAddr,
      _ronChainId
    );

    vm.prank(user.addr, user.addr);
    vm.expectEmit(address(ETH_GATEWAY_CONTRACT));
    emit DepositRequested(receipt.hash(), receipt);
    MainchainGatewayV3(payable(address(ETH_GATEWAY_CONTRACT))).requestDepositFor{ value: 1 ether }(request);

    vm.selectFork(_roninFork);
    address operator = _operators[0];
    vm.prank(operator, operator);
    RoninGatewayV3(payable(address(RONIN_GATEWAY_CONTRACT))).depositFor(receipt);
  }

  function test_Fork_VoteAddBridgeOperators() external onWhichFork(_roninFork) {
    uint256 r1 = 0;
    uint256 r2 = 1;
    uint256 r3 = 2;
    uint256 numBridgeOperators = 3;

    (address[] memory operators, address[] memory governors, uint96[] memory weights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );
    uint256 deadline = block.timestamp + DEFAULT_EXPIRY_DURATION;

    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = GlobalProposal.TargetOption.BridgeManager;

    uint256[] memory values = new uint256[](1);
    uint256[] memory gasAmounts = new uint256[](1);
    gasAmounts[0] = DEFAULT_GAS;
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeCall(BridgeManager.addBridgeOperators, (weights, governors, operators));

    GlobalProposal.GlobalProposalDetail memory proposal = GlobalProposal.GlobalProposalDetail(
      1,
      deadline,
      targetOptions,
      values,
      calldatas,
      gasAmounts
    );

    bytes32 digest = ECDSA.toTypedDataHash(
      _ronBridgeManagerContract.DOMAIN_SEPARATOR(),
      Ballot.hash(proposal.hash(), Ballot.VoteType.For)
    );
    uint256 length = DEFAULT_NUM_BRIDGE_OPERATORS;
    Signature[] memory sigs = new Signature[](length);
    uint256[] memory pks = new uint256[](length);
    for (uint256 i; i < length; ) {
      pks[i] = _getGovernorPrivateKey(i);
      unchecked {
        ++i;
      }
    }
    uint256[] memory uintGovernors;
    address[] memory __governors = _governors;
    assembly {
      uintGovernors := __governors
    }
    pks = pks.sort(uintGovernors);
    for (uint256 i; i < length; ) {
      (sigs[i].v, sigs[i].r, sigs[i].s) = vm.sign(pks[length - i - 1], digest);

      unchecked {
        ++i;
      }
    }

    Ballot.VoteType[] memory supportsType = new Ballot.VoteType[](length);
    for (uint256 i; i < length; ) {
      supportsType[i] = Ballot.VoteType.For;
      unchecked {
        ++i;
      }
    }

    address governor = _governors[0];
    vm.prank(governor, governor);
    _ronBridgeManagerContract.proposeGlobalProposalStructAndCastVotes(proposal, supportsType, sigs);

    vm.selectFork(_ethFork);
    vm.warp(block.timestamp + DEFAULT_EXPIRY_DURATION + 1 days);
    vm.prank(governor, governor);
    _ethBridgeManagerContract.relayGlobalProposal(proposal, supportsType, sigs);
  }

  function _createFork() internal virtual override {
    _ethFork = vm.createSelectFork(GOERLI_RPC);
    _ethChainId = block.chainid;

    _roninFork = vm.createSelectFork(RONIN_TEST_RPC, FORK_HEIGHT);
    _ronChainId = block.chainid;
  }

  function _setUpOnETH() internal onWhichFork(_ethFork) {
    address[] memory callbackRegisters;
    address[] memory targets;
    GlobalProposal.TargetOption[] memory targetOptions;
    // deploy MainchainBridgeManager
    _ethBridgeManagerContract = MainchainBridgeManager(
      payable(
        deployImmutable({
          contractName: type(MainchainBridgeManager).name,
          creationCode: type(MainchainBridgeManager).creationCode,
          params: abi.encode(
            DEFAULT_NUMERATOR,
            DEFAULT_DENOMINATOR,
            _ronChainId,
            RONIN_GATEWAY_CONTRACT,
            callbackRegisters,
            _operators,
            _governors,
            _weights,
            targets,
            targetOptions
          ),
          value: ZERO_VALUE
        })
      )
    );

    // upgrade MainchainGatewayV3
    upgradeToAndCall({
      proxy: ETH_GATEWAY_CONTRACT,
      contractName: type(MainchainGatewayV3).name,
      logicCode: type(MainchainGatewayV3).creationCode,
      callData: abi.encodeCall(MainchainGatewayV3.initializeV2, (address(_ethBridgeManagerContract)))
    });
  }

  function _setUpOnRON() internal onWhichFork(_roninFork) {
    // register BridgeSlash as callback receiver
    address[] memory callbackRegisters = new address[](1);
    // precompute BridgeSlash address
    callbackRegisters[0] = _computeAddress({
      contractName: _getProxyLabel(type(BridgeSlash).name),
      creationCode: type(TransparentUpgradeableProxyV3).creationCode,
      params: EMPTY_PARAM
    });

    address[] memory targets;
    GlobalProposal.TargetOption[] memory targetOptions;
    // precompute RoninBridgeManager address
    bytes memory bridgeManagerParams = abi.encode(
      DEFAULT_NUMERATOR,
      DEFAULT_DENOMINATOR,
      _ronChainId,
      DEFAULT_EXPIRY_DURATION,
      RONIN_GATEWAY_CONTRACT,
      callbackRegisters,
      _operators,
      _governors,
      _weights,
      targetOptions,
      targets
    );
    address bridgeManagerContract = _computeAddress({
      contractName: type(RoninBridgeManager).name,
      creationCode: type(RoninBridgeManager).creationCode,
      params: bridgeManagerParams
    });

    // deploy BridgeSlash
    (_ronBridgeSlashProxy, ) = deployProxy({
      contractName: type(BridgeSlash).name,
      logicCode: type(BridgeSlash).creationCode,
      proxyAdmin: _defaultAdmin,
      value: ZERO_VALUE,
      callData: abi.encodeCall(
        BridgeSlash.initialize,
        (
          address(RONIN_VALIDATOR_SET_CONTRACT),
          bridgeManagerContract,
          address(RONIN_BRIDGE_TRACKING_CONTRACT),
          address(0)
        )
      )
    });

    // deploy BridgeReward
    (_ronBridgeRewardProxy, ) = deployProxy({
      contractName: type(BridgeReward).name,
      logicCode: type(BridgeReward).creationCode,
      proxyAdmin: _defaultAdmin,
      value: ZERO_VALUE,
      callData: abi.encodeCall(
        BridgeReward.initialize,
        (
          bridgeManagerContract,
          address(RONIN_BRIDGE_TRACKING_CONTRACT),
          address(_ronBridgeSlashProxy),
          address(RONIN_VALIDATOR_SET_CONTRACT),
          address(0),
          DEFAULT_REWARD_PER_PERIOD
        )
      )
    });

    // deploy RoninBridgeManager
    _ronBridgeManagerContract = RoninBridgeManager(
      payable(
        deployImmutable({
          contractName: type(RoninBridgeManager).name,
          creationCode: type(RoninBridgeManager).creationCode,
          params: bridgeManagerParams,
          value: ZERO_VALUE
        })
      )
    );

    // upgrade RoninGatewayV3
    upgradeToAndCall({
      proxy: RONIN_GATEWAY_CONTRACT,
      contractName: type(RoninGatewayV3).name,
      logicCode: type(RoninGatewayV3).creationCode,
      callData: abi.encodeCall(RoninGatewayV3.initializeV3, (address(_ronBridgeManagerContract)))
    });

    // upgrade BridgeTracking
    (, address proxyAdmin) = upgradeTo(
      RONIN_BRIDGE_TRACKING_CONTRACT,
      type(BridgeTracking).name,
      type(BridgeTracking).creationCode
    );

    vm.startPrank(proxyAdmin, proxyAdmin);
    RONIN_BRIDGE_TRACKING_CONTRACT.functionDelegateCall(abi.encodeCall(BridgeTracking.initializeV2, ()));
    RONIN_BRIDGE_TRACKING_CONTRACT.functionDelegateCall(
      abi.encodeCall(
        BridgeTracking.initializeV3,
        (address(_ronBridgeManagerContract), address(_ronBridgeSlashProxy), address(_ronBridgeRewardProxy), address(0))
      )
    );
    vm.stopPrank();
  }

  function createBridgeOperatorInfo()
    public
    returns (address[] memory governors, address[] memory operators, uint96[] memory weights)
  {
    uint256 length = DEFAULT_NUM_BRIDGE_OPERATORS;

    weights = new uint96[](length);
    governors = new address[](length);
    operators = new address[](length);

    uint96 weight = uint96(DEFAULT_WEIGHT);
    uint256 defaultBalance = DEFAULT_BALANCE;

    for (uint256 i; i < length; ) {
      weights[i] = weight;
      governors[i] = _createPersistentAccount(_getGovernorPrivateKey(i), defaultBalance);
      operators[i] = _createPersistentAccount(_getOperatorPrivateKey(i), defaultBalance);

      unchecked {
        ++i;
      }
    }
  }

  function _getOperatorPrivateKey(uint256 idx) internal pure returns (uint256) {
    return boundPrivateKey(INITIAL_SEED + idx);
  }

  function _getGovernorPrivateKey(uint256 idx) internal pure returns (uint256) {
    return boundPrivateKey(~(INITIAL_SEED + idx));
  }
}
