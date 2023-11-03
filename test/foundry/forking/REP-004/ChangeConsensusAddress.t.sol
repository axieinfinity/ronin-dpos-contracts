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
import { ICandidateManager, RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
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
    _upgradeContracts();
    _;
  }

  function _upgradeContracts() internal {
    _upgradeProfile();
    _upgradeStaking();
    _upgradeValidator();
    _upgradeMaintenance();
    _upgradeSlashIndicator();
  }

  function setUp() external {
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

    vm.createSelectFork(RONIN_TEST_RPC, 21710591);
  }

  function testFork_AfterUpgraded_ChangeConsensusAddress() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("new-consensus-0"));

    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    newConsensus = TConsensus.wrap(makeAddr("new-consensus-1"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function testFork_AfterUpgrade_WrapUpEpochAndNonWrapUpEpoch_ChangeAdmin_ChangeConsensus_ChangeTreasury() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address cid = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(cid)).__shadowedAdmin;

    // change validator admin
    address newAdmin = makeAddr("new-admin");
    address newConsensus = makeAddr("new-consensus");
    address payable newTreasury = payable(makeAddr("new-treasury"));

    vm.startPrank(candidateAdmin);
    _profile.requestChangeConsensusAddr(cid, TConsensus.wrap(newConsensus));
    _profile.requestChangeTreasuryAddr(cid, newTreasury);
    _profile.requestChangeAdminAddress(cid, newAdmin);
    vm.stopPrank();

    // store snapshot state
    uint256 snapshotId = vm.snapshot();

    // wrap up epoch
    _fastForwardToNextDay();
    _wrapUpEpoch();

    ICandidateManager.ValidatorCandidate memory wrapUpInfo = _validator.getCandidateInfo(TConsensus.wrap(newConsensus));
    ICandidateManager.ValidatorCandidate[] memory wrapUpInfos = _validator.getCandidateInfos();

    // revert to state before wrap up
    vm.revertTo(snapshotId);
    ICandidateManager.ValidatorCandidate memory nonWrapUpInfo = _validator.getCandidateInfo(
      TConsensus.wrap(newConsensus)
    );
    ICandidateManager.ValidatorCandidate[] memory nonWrapUpInfos = _validator.getCandidateInfos();

    assertEq(wrapUpInfo.__shadowedAdmin, nonWrapUpInfo.__shadowedAdmin);
    assertEq(wrapUpInfo.__shadowedAdmin, newAdmin);
    assertEq(TConsensus.unwrap(wrapUpInfo.__shadowedConsensus), TConsensus.unwrap(nonWrapUpInfo.__shadowedConsensus));
    assertEq(TConsensus.unwrap(wrapUpInfo.__shadowedConsensus), newConsensus);
    assertEq(wrapUpInfo.__shadowedTreasury, nonWrapUpInfo.__shadowedTreasury);
    assertEq(wrapUpInfo.__shadowedTreasury, newTreasury);
    assertEq(wrapUpInfo.commissionRate, nonWrapUpInfo.commissionRate);
    assertEq(wrapUpInfo.revokingTimestamp, nonWrapUpInfo.revokingTimestamp);
    assertEq(wrapUpInfo.topupDeadline, nonWrapUpInfo.topupDeadline);

    IProfile.CandidateProfile memory mProfile = _profile.getId2Profile(cid);
    assertEq(mProfile.id, cid);
    assertEq(TConsensus.unwrap( mProfile.consensus), newConsensus);
    assertEq(mProfile.admin, newAdmin);
    assertEq(mProfile.treasury, newTreasury);

    assertEq(wrapUpInfos.length, nonWrapUpInfos.length);
    for (uint256 i; i < wrapUpInfos.length; ++i) {
      assertEq(keccak256(abi.encode(wrapUpInfos[i])), keccak256(abi.encode(nonWrapUpInfos[i])));
    }
  }

  function testFork_SlashIndicator_BeforeAndAfterUpgrade() external {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;

    uint256 snapshotId = vm.snapshot();

    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;
    console2.log("before-upgrade:recipient", recipient);
    uint256 balanceBefore = recipient.balance;
    console2.log("before-upgrade:balanceBefore", balanceBefore);

    _bulkSlashIndicator(validatorCandidate, 50);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    uint256 balanceAfter = recipient.balance;
    console2.log("before-upgrade:balanceAfter", balanceAfter);
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;
    console2.log("before-upgrade:reward", beforeUpgradeReward);
    assertFalse(_validator.isBlockProducer(TConsensus.wrap(validatorCandidate)));

    vm.revertTo(snapshotId);
    _upgradeContracts();
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkSlashIndicator(TConsensus.unwrap(newConsensus), 50);

    console2.log("new-consensus", TConsensus.unwrap(newConsensus));

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    console2.log("after-upgrade:recipient", recipient);

    balanceBefore = recipient.balance;
    console2.log("after-upgrade:balanceBefore", balanceBefore);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    balanceAfter = recipient.balance;
    console2.log("after-upgrade:balanceAfter", balanceBefore);
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;
    console2.log("after-upgrade:reward", afterUpgradedReward);

    assertFalse(_validator.isBlockProducer(newConsensus));
    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
  }

  function _bulkSlashIndicator(address consensus, uint256 times) internal {
    vm.startPrank(block.coinbase);
    for (uint256 i; i < times; ++i) {
      _slashIndicator.slashUnavailability(TConsensus.wrap(consensus));
      vm.roll(block.number + i + 1);
    }
    vm.stopPrank();
  }

  function testFork_Maintenance_BeforeAndAfterUpgrade() external {
    // upgrade maintenance
    vm.prank(_getProxyAdmin(address(_maintenance)));
    TransparentUpgradeableProxyV2(payable(address(_maintenance))).upgradeTo(0x84d6e16a767A85D34964f26094BB46b0b7a4c8Ab);

    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;

    // check balance before wrapup epoch
    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;
    console2.log("before-upgrade:recipient", recipient);
    uint256 balanceBefore = recipient.balance;
    console2.log("before-upgrade:balanceBefore", balanceBefore);

    // save snapshot state before wrapup
    uint256 snapshotId = vm.snapshot();

    bulkSubmitBlockReward(1);

    uint256 minOffsetToStartSchedule = _maintenance.minOffsetToStartSchedule();
    uint256 latestEpoch = _validator.getLastUpdatedBlock() + 200;
    this.schedule(
      candidateAdmin,
      validatorCandidate,
      latestEpoch + 1 + minOffsetToStartSchedule,
      latestEpoch + minOffsetToStartSchedule + _maintenance.minMaintenanceDurationInBlock()
    );
    vm.roll(latestEpoch + minOffsetToStartSchedule + 200);

    _bulkSlashIndicator(validatorCandidate, 50);
    _bulkWrapUpEpoch(1);

    assertFalse(_validator.isBlockProducer(TConsensus.wrap(validatorCandidate)));
    uint256 balanceAfter = recipient.balance;
    console2.log("before-upgrade:balanceAfter", balanceAfter);
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;
    console2.log("before-upgrade:reward", beforeUpgradeReward);

    // revert to previous state
    vm.revertTo(snapshotId);
    _upgradeContracts();
    // change consensus address
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    console2.log("after-upgrade:recipient", recipient);
    balanceBefore = recipient.balance;
    console2.log("after-upgrade:balanceBefore", balanceBefore);

    bulkSubmitBlockReward(1);

    this.schedule(
      candidateAdmin,
      TConsensus.unwrap(newConsensus),
      latestEpoch + 1 + minOffsetToStartSchedule,
      latestEpoch + minOffsetToStartSchedule + _maintenance.minMaintenanceDurationInBlock()
    );
    vm.roll(latestEpoch + minOffsetToStartSchedule + 200);

    _bulkSlashIndicator(TConsensus.unwrap(newConsensus), 50);
    _bulkWrapUpEpoch(1);

    assertFalse(_validator.isBlockProducer(newConsensus));
    balanceAfter = recipient.balance;
    console2.log("after-upgrade:balanceAfter", balanceBefore);
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;
    console2.log("after-upgrade:reward", afterUpgradedReward);
    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
  }

  function bulkSubmitBlockReward(uint256 times) internal {
    for (uint256 i; i < times; ++i) {
      vm.roll(block.number + 1);
      vm.deal(block.coinbase, 1000 ether);
      vm.prank(block.coinbase);
      _validator.submitBlockReward{ value: 1000 ether }();
    }
  }

  function testFork_schedule() external {
    vm.prank(_getProxyAdmin(address(_maintenance)));
    TransparentUpgradeableProxyV2(payable(address(_maintenance))).upgradeTo(0x84d6e16a767A85D34964f26094BB46b0b7a4c8Ab);

    vm.prank(0x29E8428cA857feA6C419a7193d475f8b06712126);
    _maintenance.schedule(TConsensus.wrap(0xCaba9D9424D6bAD99CE352A943F59279B533417a), 21710591, 21710599);
  }

  function schedule(address admin, address consensus, uint256 startAtBlock, uint256 endedAtBlock) external {
    vm.prank(admin);
    _maintenance.schedule(TConsensus.wrap(consensus), startAtBlock, endedAtBlock);
  }

  function _bulkWrapUpEpoch(uint256 times) internal {
    for (uint256 i; i < times; ++i) {
      _fastForwardToNextDay();
      _wrapUpEpoch();
    }
  }

  function testFork_ShareSameSameReward_BeforeAndAfterUpgrade() external {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    //address recipient = candidateAdmin;
    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;
    console2.log("before-upgrade:recipient", recipient);
    uint256 balanceBefore = recipient.balance;
    console2.log("before-upgrade:balanceBefore", balanceBefore);
    uint256 snapshotId = vm.snapshot();

    _fastForwardToNextDay();
    _wrapUpEpoch();

    uint256 balanceAfter = recipient.balance;
    console2.log("before-upgrade:balanceAfter", balanceAfter);
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;
    console2.log("before-upgrade:reward", beforeUpgradeReward);

    vm.revertTo(snapshotId);
    _upgradeContracts();
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    console2.log("new-consensus", TConsensus.unwrap(newConsensus));

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    console2.log("after-upgrade:recipient", recipient);

    balanceBefore = recipient.balance;
    console2.log("after-upgrade:balanceBefore", balanceBefore);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    balanceAfter = recipient.balance;
    console2.log("after-upgrade:balanceAfter", balanceBefore);
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;
    console2.log("after-upgrade:reward", afterUpgradedReward);

    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
  }

  function testFailFork_RevertWhen_AfterUpgraded_DifferentAdmins_ShareSameConsensusAddr() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function testFork_AfterUpgraded_applyValidatorCandidate() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");
    _applyValidatorCandidate("candidate-admin-1", "consensus-1");

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function testFork_AfterUpgraded_applyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");

    _fastForwardToNextDay();
    _wrapUpEpoch();

    _applyValidatorCandidate("candidate-admin-1", "consensus-1");
  }

  function testFailFork_RevertWhen_AfterUpgraded_ReapplyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin", "consensus");

    _fastForwardToNextDay();
    _wrapUpEpoch();

    _applyValidatorCandidate("candidate-admin", "consensus");
  }

  function testFailFork_RevertWhen_AfterUpgraded_ReapplyValidatorCandidate() external upgrade {
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
    TransparentUpgradeableProxyV2(payable(address(_maintenance))).upgradeToAndCall(
      address(logic),
      abi.encodeCall(Maintenance.initializeV3, (address(_profile)))
    );
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
