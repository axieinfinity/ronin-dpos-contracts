// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { LibArrayUtils } from "../helpers/LibArrayUtils.t.sol";
import { IBridgeRewardEvents } from "./interfaces/IBridgeRewardEvents.t.sol";
import { IBridgeManager, BridgeManagerUtils } from "./utils/BridgeManagerUtils.t.sol";
import { MockValidatorContract } from "@ronin/contracts/mocks/ronin/MockValidatorContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { IBridgeSlash, MockBridgeSlash, BridgeSlash } from "@ronin/contracts/mocks/ronin/MockBridgeSlash.sol";
import { IBridgeReward, MockBridgeReward, BridgeReward } from "@ronin/contracts/mocks/ronin/MockBridgeReward.sol";

contract BridgeRewardTest is Test, IBridgeRewardEvents, BridgeManagerUtils {
  using LibArrayUtils for uint256[];

  uint256 internal constant DEFAULT_REWARD_PER_PERIOD = 1 ether;

  address internal _admin;
  address internal _validatorContract;
  address internal _bridgeRewardLogic;
  address internal _bridgeManagerContract;
  address internal _bridgeRewardContract;
  address internal _bridgeSlashLogic;
  address internal _bridgeSlashContract;
  address internal _bridgeTrackingContract;
  address internal _bridgeTrackingLogic;

  bytes internal _defaultBridgeManagerInputs;

  function setUp() external {
    _setUp();
    _label();
  }

  function test_Fuzz_RewardCalculationLogic(uint256 r1, uint256 r2, uint256 totalVotes, uint256 period) external {
    vm.assume(r1 != r2);

    period = _bound(period, 1, type(uint64).max);

    (address[] memory bridgeOperators, , ) = abi.decode(_defaultBridgeManagerInputs, (address[], address[], uint256[]));

    uint256[] memory slashUntils = _createRandomNumbers(r1, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);
    uint256[] memory ballots = _createRandomNumbers(r2, bridgeOperators.length, 0, MAX_FUZZ_INPUTS);

    MockBridgeReward bridgeRewardContract = MockBridgeReward(payable(_bridgeRewardContract));

    uint256 totalBallots = ballots.sum();
    bool isValidResponse = bridgeRewardContract.isValidBridgeTrackingResponse(totalBallots, totalVotes, ballots);

    uint256 rewardPerPeriod = IBridgeReward(_bridgeRewardContract).getRewardPerPeriod();

    if (totalBallots == 0) {
      assertTrue(!isValidResponse);
    }
    if (isValidResponse) {
      _assertCalculateRewardProportionally(
        isValidResponse,
        rewardPerPeriod,
        totalBallots,
        bridgeRewardContract,
        ballots
      );
    } else {
      _assertCalculateRewardEqually(isValidResponse, rewardPerPeriod, totalBallots, bridgeRewardContract, ballots);
    }
    _assertSlashBridgeOperators(period, slashUntils, bridgeRewardContract);
  }

  function _assertCalculateRewardProportionally(
    bool isValidResponse,
    uint256 rewardPerPeriod,
    uint256 totalBallots,
    MockBridgeReward bridgeRewardContract,
    uint256[] memory ballots
  ) internal {
    assertTrue(isValidResponse);
    uint256 length = ballots.length;

    uint256 actual;
    uint256 expected;
    for (uint256 i; i < length; ) {
      actual = bridgeRewardContract.calcReward(isValidResponse, length, rewardPerPeriod, ballots[i], totalBallots);
      expected = (rewardPerPeriod * ballots[i]) / totalBallots;

      assertTrue(actual == expected);

      unchecked {
        ++i;
      }
    }
  }

  function _assertCalculateRewardEqually(
    bool isValidResponse,
    uint256 rewardPerPeriod,
    uint256 totalBallots,
    MockBridgeReward bridgeRewardContract,
    uint256[] memory ballots
  ) internal {
    assertTrue(!isValidResponse);
    uint256 actual;
    uint256 length = ballots.length;
    uint256 expected = rewardPerPeriod / length;

    for (uint256 i; i < length; ) {
      console.log("actual", actual);
      console.log("expected", expected);
      actual = bridgeRewardContract.calcReward(isValidResponse, length, rewardPerPeriod, ballots[i], totalBallots);
      assertTrue(actual == expected);

      unchecked {
        ++i;
      }
    }
  }

  function _assertSlashBridgeOperators(
    uint256 period,
    uint256[] memory slashUntils,
    MockBridgeReward bridgeRewardContract
  ) internal {
    uint256 length = slashUntils.length;
    for (uint256 i; i < length; ) {
      if (period <= slashUntils[i]) {
        assertTrue(bridgeRewardContract.isSlashedThisPeriod(period, slashUntils[i]));
      }

      unchecked {
        ++i;
      }
    }
  }

  function _setUp() internal virtual {
    _admin = vm.addr(1);

    _validatorContract = address(new MockValidatorContract());

    (address[] memory bridgeOperators, address[] memory governors, uint256[] memory voteWeights) = getValidInputs(
      DEFAULT_R1,
      DEFAULT_R2,
      DEFAULT_R3,
      DEFAULT_NUM_BRIDGE_OPERATORS
    );

    _defaultBridgeManagerInputs = abi.encode(bridgeOperators, governors, voteWeights);

    _bridgeManagerContract = address(new MockBridgeManager(bridgeOperators, governors, voteWeights));

    _bridgeTrackingLogic = address(new BridgeTracking());
    _bridgeTrackingContract = address(new TransparentUpgradeableProxy(_bridgeTrackingLogic, _admin, ""));

    _bridgeSlashLogic = address(new MockBridgeSlash());
    _bridgeSlashContract = address(
      new TransparentUpgradeableProxy(
        _bridgeSlashLogic,
        _admin,
        abi.encodeCall(BridgeSlash.initialize, (_validatorContract, _bridgeManagerContract, _bridgeTrackingContract))
      )
    );

    _bridgeRewardLogic = address(new MockBridgeReward());
    _bridgeRewardContract = address(
      new TransparentUpgradeableProxy(
        _bridgeRewardLogic,
        _admin,
        abi.encodeCall(
          BridgeReward.initialize,
          (_bridgeManagerContract, _bridgeTrackingContract, _bridgeSlashContract, DEFAULT_REWARD_PER_PERIOD)
        )
      )
    );
  }

  function _label() internal virtual {
    vm.label(_admin, "ADMIN");
    vm.label(_validatorContract, "VALIDATOR");
    vm.label(_bridgeManagerContract, "BRIDGE_MANAGER");
    vm.label(_bridgeTrackingLogic, "BRIDGE_TRACKING_LOGIC");
    vm.label(_bridgeTrackingContract, "BRIDGE_TRACKING");
    vm.label(_bridgeSlashLogic, "BRIDGE_SLASH_LOGIC");
    vm.label(_bridgeSlashContract, "BRIDGE_SLASH");
    vm.label(_bridgeRewardLogic, "BRIDGE_REWARD_LOGIC");
    vm.label(_bridgeRewardContract, "BRIDGE_REWARD_CONTRACT");
  }
}
