// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
  BridgeTracking internal _bridgeTracking;
  SlashIndicator internal _slashIndicator;
  RoninValidatorSet internal _validatorSet;
  RoninTrustedOrganization internal _trustedOrgs;
  StakingVesting internal _stakingVesting;
  FastFinalityTracking internal _fastFinalityTracking;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(ContractKey.Profile, new ProfileDeploy());
  }

  function run() public virtual trySetUp {
    {
      address mockPrecompile = _deployImmutable(ContractKey.MockPrecompile, EMPTY_ARGS);
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));
    }
  }

  function _depositFor(string memory userName) internal {
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
    RoninGatewayV2 roninGateway = RoninGatewayV2(_config.getAddressFromCurrentNetwork(ContractKey.RoninGatewayV2));

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
    roninGateway.depositFor(receipt);
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
}
