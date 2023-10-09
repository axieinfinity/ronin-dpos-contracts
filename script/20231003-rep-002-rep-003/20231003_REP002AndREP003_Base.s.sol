// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { MainchainGatewayV2 } from "@ronin/contracts/mainchain/MainchainGatewayV2.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { MappedTokenConsumer } from "@ronin/contracts/interfaces/consumers/MappedTokenConsumer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { console2, BaseDeploy, ContractKey, Network } from "../BaseDeploy.s.sol";
import { RoninValidatorSet, RoninValidatorSetTimedMigratorUpgrade } from "./contracts/RoninValidatorSetTimedMigratorUpgrade.s.sol";
import { ProfileDeploy } from "./contracts/ProfileDeploy.s.sol";
import { NotifiedMigratorUpgrade } from "./contracts/NotifiedMigratorUpgrade.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_Base is BaseDeploy, MappedTokenConsumer {
  using Transfer for *;

  Staking internal _staking;
  RoninGatewayV2 internal _roninGateway;
  BridgeTracking internal _bridgeTracking;
  SlashIndicator internal _slashIndicator;
  RoninValidatorSet internal _validatorSet;
  StakingVesting internal _stakingVesting;
  RoninTrustedOrganization internal _trustedOrgs;
  FastFinalityTracking internal _fastFinalityTracking;
  RoninGovernanceAdmin internal _roninGovernanceAdmin;

  // new contracts
  BridgeSlash internal _bridgeSlash;
  BridgeReward internal _bridgeReward;
  RoninBridgeManager internal _roninBridgeManager;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(ContractKey.Profile, new ProfileDeploy());
  }

  function run() public virtual trySetUp {
    {
      address mockPrecompile = _deployLogic(ContractKey.MockPrecompile);
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));
    }

    _staking = Staking(_config.getAddressFromCurrentNetwork(ContractKey.Staking));
    _roninGateway = RoninGatewayV2(_config.getAddressFromCurrentNetwork(ContractKey.RoninGatewayV2));
    _bridgeTracking = BridgeTracking(_config.getAddressFromCurrentNetwork(ContractKey.BridgeTracking));
    _slashIndicator = SlashIndicator(_config.getAddressFromCurrentNetwork(ContractKey.SlashIndicator));
    _stakingVesting = StakingVesting(_config.getAddressFromCurrentNetwork(ContractKey.StakingVesting));
    _validatorSet = RoninValidatorSet(_config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet));
    _trustedOrgs = RoninTrustedOrganization(_config.getAddressFromCurrentNetwork(ContractKey.RoninTrustedOrganization));
    _fastFinalityTracking = FastFinalityTracking(
      _config.getAddressFromCurrentNetwork(ContractKey.FastFinalityTracking)
    );
    _roninGovernanceAdmin = RoninGovernanceAdmin(_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin));
  }

  function _depositForOnBothChain(string memory userName) internal {
    Account memory user = makeAccount(userName);
    vm.makePersistent(user.addr);
    vm.deal(user.addr, 1000 ether);

    Transfer.Request memory request = Transfer.Request(
      user.addr,
      address(0),
      Token.Info(Token.Standard.ERC20, 0, 1 ether)
    );

    MainchainGatewayV2 mainchainGateway = MainchainGatewayV2(
      _config.getAddress(Network.EthMainnet, ContractKey.MainchainGatewayV2)
    );

    // switch rpc to eth mainnet
    _config.switchTo(Network.EthMainnet);

    address weth = address(mainchainGateway.wrappedNativeToken());
    MappedTokenConsumer.MappedToken memory token = mainchainGateway.getRoninToken(weth);

    Transfer.Receipt memory receipt = Transfer.Request(user.addr, weth, request.info).into_deposit_receipt(
      user.addr,
      mainchainGateway.depositCount(),
      token.tokenAddr,
      2020 // ronin-mainnet chainId
    );

    vm.prank(user.addr);
    mainchainGateway.requestDepositFor{ value: 1 ether }(request);

    // switch rpc to ronin mainnet
    _config.switchTo(Network.RoninMainnet);

    address operator = 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA;
    vm.label(operator, "bridge-operator");
    vm.prank(operator);
    _roninGateway.depositFor(receipt);
  }

  // uint256 _depositCount = 42127; // fork-block-number 28139075
  uint256 _depositCount = 42213; // fork-block-number 28327195
  function _depositForOnlyOnRonin(string memory userName) internal {
    Account memory user = makeAccount(userName);
    vm.makePersistent(user.addr);
    vm.deal(user.addr, 1000 ether);

    Transfer.Request memory request = Transfer.Request(
      user.addr,
      address(0),
      Token.Info(Token.Standard.ERC20, 0, 1 ether)
    );

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address roninToken = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;
    Transfer.Receipt memory receipt = Transfer.Request(user.addr, weth, request.info).into_deposit_receipt(
      user.addr,
      _depositCount++,
      roninToken,
      2020 // ronin-mainnet chainId
    );
    receipt.mainchain.chainId = 1;

    // address operator = 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA;
    // vm.label(operator, "bridge-operator");
    // vm.prank(operator);
    vm.prank(makeAccount("detach-operator-1").addr);
    _roninGateway.depositFor(receipt);
  }

  function _dummySwitchNetworks() internal {
    _config.switchTo(Network.EthMainnet);
    _config.switchTo(Network.RoninMainnet);
  }

  function _wrapUpEpoch() internal {
    vm.prank(block.coinbase);
    _validatorSet.wrapUpEpoch();
  }

  function _fastForwardToNextDay() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = _validatorSet.numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);
    uint256 nextDayTimestamp = block.timestamp + 1 days;

    // fast forward to next day
    vm.warp(nextDayTimestamp);
    vm.roll(epochEndingBlockNumber);
  }

  function _fastForwardToNextEpoch() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = _validatorSet.numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);

    // fast forward to next day
    vm.roll(epochEndingBlockNumber);
  }
}
