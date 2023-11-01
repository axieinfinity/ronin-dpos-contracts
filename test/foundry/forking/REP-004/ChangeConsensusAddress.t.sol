// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { IProfile, Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { HasContracts } from "@ronin/contracts/extensions/collections/HasContracts.sol";
import { CandidateManager } from "@ronin/contracts/ronin/validator/CandidateManager.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract ChangeConsensusAddressForkTest is Test {
  string constant RONIN_TEST_RPC = "https://saigon-archive.roninchain.com/rpc";
  bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  Profile internal _profile;
  Staking internal _staking;
  Maintenance internal _maintenance;
  RoninValidatorSet internal _validator;
  SlashIndicator internal _slashIndicator;

  modifier upgrade() {
    _upgradeProfile();
    _upgradeStaking();
    _upgradeValidator();
    _upgradeMaintenance();
    _upgradeSlashIndicator();
    _;
  }

  function setUp() external {
    vm.createSelectFork(RONIN_TEST_RPC, 21710591);

    MockPrecompile mockPrecompile = new MockPrecompile();
    vm.etch(address(0x68), address(mockPrecompile).code);
    vm.makePersistent(address(0x68));

    _profile = Profile(0x3b67c8D22a91572a6AB18acC9F70787Af04A4043);
    _staking = Staking(payable(0x9C245671791834daf3885533D24dce516B763B28));
    _slashIndicator = SlashIndicator(0xF7837778b6E180Df6696C8Fa986d62f8b6186752);
    _maintenance = Maintenance(0x4016C80D97DDCbe4286140446759a3f0c1d20584);
    _validator = RoninValidatorSet(payable(0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d));

    vm.label(address(_profile), "Profile");
    vm.label(address(_staking), "Staking");
    vm.label(address(_validator), "Validator");
    vm.label(address(_maintenance), "Maintenance");
    vm.label(address(_slashIndicator), "SlashIndicator");
  }

  function test_AfterUpgraded_ChangeConsensusAddress() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).admin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("new-consensus-0"));
    
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).admin;
    newConsensus = TConsensus.wrap(makeAddr("new-consensus-1"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function testFail_RevertWhen_AfterUpgraded_DifferentAdmins_ShareSameConsensusAddr() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).admin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).admin;
    newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function test_AfterUpgraded_applyValidatorCandidate() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");
    _applyValidatorCandidate("candidate-admin-1", "consensus-1");

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function test_AfterUpgraded_applyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");

    _fastForwardToNextDay();
    _wrapUpEpoch();

    _applyValidatorCandidate("candidate-admin-1", "consensus-1");
  }

  function testFail_RevertWhen_AfterUpgraded_ReapplyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin", "consensus");

    _fastForwardToNextDay();
    _wrapUpEpoch();

    _applyValidatorCandidate("candidate-admin", "consensus");
  }

  function testFail_RevertWhen_AfterUpgraded_ReapplyValidatorCandidate() external upgrade {
    _applyValidatorCandidate("candidate-admin", "consensus");
    _applyValidatorCandidate("candidate-admin", "consensus");
  }

  function _upgradeProfile() internal {
    Profile logic = new Profile();
    vm.prank(_getProxyAdmin(address(_profile)));
    TransparentUpgradeableProxyV2(payable(address(_profile))).upgradeToAndCall(
      address(logic),
      abi.encodeCall(Profile.initializeV2, address(_staking))
    );
    _profile.initializeV3();
  }

  function _upgradeMaintenance() internal {
    Maintenance logic = new Maintenance();
    vm.prank(_getProxyAdmin(address(_maintenance)));
    TransparentUpgradeableProxyV2(payable(address(_maintenance))).upgradeTo(address(logic));
  }

  function _upgradeSlashIndicator() internal {
    SlashIndicator logic = new SlashIndicator();
    vm.prank(_getProxyAdmin(address(_slashIndicator)));
    TransparentUpgradeableProxyV2(payable(address(_slashIndicator))).upgradeTo(address(logic));
  }

  function _upgradeStaking() internal {
    Staking logic = new Staking();
    vm.prank(_getProxyAdmin(address(_staking)));
    TransparentUpgradeableProxyV2(payable(_staking)).upgradeToAndCall(
      address(logic),
      abi.encodeCall(Staking.initializeV3, (address(_profile)))
    );
  }

  function _upgradeValidator() internal {
    RoninValidatorSet logic = new RoninValidatorSet();
    vm.prank(_getProxyAdmin(address(_validator)));
    TransparentUpgradeableProxyV2(payable(_validator)).upgradeToAndCall(
      address(logic),
      abi.encodeCall(RoninValidatorSet.initializeV4, (address(_profile)))
    );
  }

  function _getProxyAdmin(address proxy) internal view returns (address payable proxyAdmin) {
    return payable(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
  }

  function _wrapUpEpoch() internal {
    vm.prank(block.coinbase);
    _validator.wrapUpEpoch();
  }

  function _fastForwardToNextDay() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = _validator.numberOfBlocksInEpoch();

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

    uint256 numberOfBlocksInEpoch = _validator.numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);

    // fast forward to next day
    vm.roll(epochEndingBlockNumber);
  }

  function _applyValidatorCandidate(string memory candidateAdminLabel, string memory consensusLabel) internal {
    address candidateAdmin = makeAddr(candidateAdminLabel);
    TConsensus consensusAddr = TConsensus.wrap(makeAddr(consensusLabel));
    bytes memory pubKey = bytes(candidateAdminLabel);

    uint256 amount = _staking.minValidatorStakingAmount();
    vm.deal(candidateAdmin, amount);
    vm.prank(candidateAdmin, candidateAdmin);
    _staking.applyValidatorCandidate{ value: amount }(
      candidateAdmin,
      consensusAddr,
      payable(candidateAdmin),
      2500,
      pubKey
    );
  }
}
