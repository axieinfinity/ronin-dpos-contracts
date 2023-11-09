// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { IProfile, Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { IBaseStaking, Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { HasContracts } from "@ronin/contracts/extensions/collections/HasContracts.sol";
import { CandidateManager } from "@ronin/contracts/ronin/validator/CandidateManager.sol";
import { EmergencyExitBallot } from "@ronin/contracts/libraries/EmergencyExitBallot.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { ICandidateManagerCallback, ICandidateManager, RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { TransparentUpgradeableProxy, TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IRoninGovernanceAdmin, RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization, RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";

contract ChangeConsensusAddressForkTest is Test {
  string constant RONIN_MAIN_RPC = "https://api-partner.roninchain.com/rpc";
  string constant RONIN_TEST_RPC = "https://saigon-archive.roninchain.com/rpc";
  bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  Profile internal _profile;
  Staking internal _staking;
  Maintenance internal _maintenance;
  RoninValidatorSet internal _validator;
  RoninGovernanceAdmin internal _roninGA;
  SlashIndicator internal _slashIndicator;
  RoninTrustedOrganization internal _roninTO;

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
    _upgradeRoninTO();
  }

  function setUp() external {
    MockPrecompile mockPrecompile = new MockPrecompile();
    vm.etch(address(0x68), address(mockPrecompile).code);
    vm.makePersistent(address(0x68));

    // vm.createSelectFork(RONIN_TEST_RPC, 21710591);
    vm.createSelectFork(RONIN_MAIN_RPC, 29225255);

    if (block.chainid == 2021) {
      _profile = Profile(0x3b67c8D22a91572a6AB18acC9F70787Af04A4043);
      _maintenance = Maintenance(0x4016C80D97DDCbe4286140446759a3f0c1d20584);
      _staking = Staking(payable(0x9C245671791834daf3885533D24dce516B763B28));
      _roninGA = RoninGovernanceAdmin(0x53Ea388CB72081A3a397114a43741e7987815896);
      _slashIndicator = SlashIndicator(0xF7837778b6E180Df6696C8Fa986d62f8b6186752);
      _roninTO = RoninTrustedOrganization(0x7507dc433a98E1fE105d69f19f3B40E4315A4F32);
      _validator = RoninValidatorSet(payable(0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d));
    }
    if (block.chainid == 2020) {
      // Mainnet
      _profile = Profile(0x840EBf1CA767CB690029E91856A357a43B85d035);
      _maintenance = Maintenance(0x6F45C1f8d84849D497C6C0Ac4c3842DC82f49894);
      _staking = Staking(payable(0x545edb750eB8769C868429BE9586F5857A768758));
      _roninGA = RoninGovernanceAdmin(0x946397deDFd2f79b75a72B322944a21C3240c9c3);
      _slashIndicator = SlashIndicator(0xEBFFF2b32fA0dF9C5C8C5d5AAa7e8b51d5207bA3);
      _roninTO = RoninTrustedOrganization(0x98D0230884448B3E2f09a177433D60fb1E19C090);
      _validator = RoninValidatorSet(payable(0x617c5d73662282EA7FfD231E020eCa6D2B0D552f));
    }

    vm.label(address(_profile), "Profile");
    vm.label(address(_staking), "Staking");
    vm.label(address(_validator), "Validator");
    vm.label(address(_maintenance), "Maintenance");
    vm.label(address(_roninGA), "GovernanceAdmin");
    vm.label(address(_roninTO), "TrustedOrganizations");
    vm.label(address(_slashIndicator), "SlashIndicator");
  }

  function testFork_AfterUpgraded_AddNewTrustedOrg_CanVoteProposal() external upgrade {
    _cheatSetRoninGACode();
    // add trusted org
    address consensus = makeAddr("consensus");
    address governor = makeAddr("governor");
    IRoninTrustedOrganization.TrustedOrganization memory newTrustedOrg = IRoninTrustedOrganization.TrustedOrganization(
      TConsensus.wrap(consensus),
      governor,
      address(0x0),
      1000,
      0
    );
    _addTrustedOrg(newTrustedOrg);

    address newLogic = address(new RoninValidatorSet());
    address[] memory targets = new address[](1);
    targets[0] = address(_validator);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, newLogic);
    uint256[] memory gasAmounts = new uint256[](1);
    gasAmounts[0] = 1_000_000;
    Ballot.VoteType support = Ballot.VoteType.For;

    vm.startPrank(governor);
    _roninGA.proposeProposalForCurrentNetwork(
      block.timestamp + 5 minutes,
      targets,
      values,
      calldatas,
      gasAmounts,
      support
    );
    vm.stopPrank();
  }

  function testFork_RevertWhen_AfterUpgraded_ApplyValidatorCandidateC1_AddNewTrustedOrgC1_ChangeC1ToC2_RenounceC2()
    external
    upgrade
  {
    // apply validator candidate
    _applyValidatorCandidate("candidate-admin", "c1");

    // add trusted org
    address consensus = makeAddr("c1");
    address governor = makeAddr("governor");
    IRoninTrustedOrganization.TrustedOrganization memory newTrustedOrg = IRoninTrustedOrganization.TrustedOrganization(
      TConsensus.wrap(consensus),
      governor,
      address(0x0),
      1000,
      0
    );
    _addTrustedOrg(newTrustedOrg);

    address newConsensus = makeAddr("c2");
    address admin = makeAddr("candidate-admin");
    vm.startPrank(admin);
    _profile.requestChangeConsensusAddr(consensus, TConsensus.wrap(newConsensus));
    vm.expectRevert(ICandidateManagerCallback.ErrTrustedOrgCannotRenounce.selector);
    _staking.requestRenounce(TConsensus.wrap(newConsensus));
    vm.stopPrank();
  }

  function testFork_AfterUpgraded_AsTrustedOrg_AfterRenouncedAndRemovedFromTO_ReAddAsTrustedOrg() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[2];

    (address admin, , ) = _staking.getPoolDetail(TConsensus.wrap(validatorCandidate));
    vm.prank(admin);
    _staking.requestRenounce(TConsensus.wrap(validatorCandidate));

    vm.warp(block.timestamp + 7 days);
    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    assertFalse(_validator.isValidatorCandidate(TConsensus.wrap(validatorCandidate)));

    IRoninTrustedOrganization.TrustedOrganization memory newTrustedOrg = IRoninTrustedOrganization.TrustedOrganization(
      TConsensus.wrap(validatorCandidate),
      makeAddr("governor"),
      address(0x0),
      1000,
      0
    );
    _addTrustedOrg(newTrustedOrg);
  }

  function testFork_AfterUpgraded_AddNewTrustedOrgBefore_ApplyValidatorCandidateAfter() external upgrade {
    uint256 newWeight = 1000;

    // add trusted org
    address consensus = makeAddr("consensus");
    address governor = makeAddr("governor");
    IRoninTrustedOrganization.TrustedOrganization memory newTrustedOrg = IRoninTrustedOrganization.TrustedOrganization(
      TConsensus.wrap(consensus),
      governor,
      address(0x0),
      newWeight,
      0
    );
    IRoninTrustedOrganization.TrustedOrganization[] memory trustedOrgs = _addTrustedOrg(newTrustedOrg);

    // apply validator candidate
    _applyValidatorCandidate("candidate-admin", "consensus");

    address newAdmin = makeAddr("new-admin");
    address admin = makeAddr("candidate-admin");
    address newTreasury = makeAddr("new-treasury");
    address newConsensus = makeAddr("new-consensus");
    vm.startPrank(admin);
    _profile.requestChangeConsensusAddr(consensus, TConsensus.wrap(newConsensus));
    _profile.requestChangeTreasuryAddr(consensus, payable(newTreasury));
    _profile.requestChangeAdminAddress(consensus, newAdmin);
    vm.stopPrank();

    // change new governor
    address newGovernor = makeAddr("new-governor");
    trustedOrgs[0].governor = newGovernor;
    trustedOrgs[0].consensusAddr = TConsensus.wrap(newConsensus);
    vm.prank(_getProxyAdmin(address(_roninTO)));
    TransparentUpgradeableProxyV2(payable(address(_roninTO))).functionDelegateCall(
      abi.encodeCall(RoninTrustedOrganization.updateTrustedOrganizations, trustedOrgs)
    );

    IProfile.CandidateProfile memory profile = _profile.getId2Profile(consensus);
    IRoninTrustedOrganization.TrustedOrganization memory trustedOrg = _roninTO.getTrustedOrganization(
      TConsensus.wrap(newConsensus)
    );

    // assert eq to updated address
    // 1.
    assertEq(trustedOrg.governor, newGovernor);
    assertEq(TConsensus.unwrap(trustedOrg.consensusAddr), newConsensus);
    assertEq(profile.id, consensus);
    assertEq(profile.treasury, payable(newTreasury));
    assertEq(profile.__reservedGovernor, address(0x0));
    assertEq(TConsensus.unwrap(profile.consensus), newConsensus);

    // 2.
    __assertWeight(TConsensus.wrap(newConsensus), consensus, newWeight);
    __assertWeight(TConsensus.wrap(consensus), consensus, 0);
  }

  function testFork_AfterUpgraded_ApplyValidatorCandidateBefore_AddNewTrustedOrgAfter() external upgrade {
    uint256 newWeight = 1000;

    // apply validator candidate
    _applyValidatorCandidate("candidate-admin", "consensus");

    // add trusted org
    address consensus = makeAddr("consensus");
    address governor = makeAddr("governor");
    IRoninTrustedOrganization.TrustedOrganization memory newTrustedOrg = IRoninTrustedOrganization.TrustedOrganization(
      TConsensus.wrap(consensus),
      governor,
      address(0x0),
      newWeight,
      0
    );
    IRoninTrustedOrganization.TrustedOrganization[] memory trustedOrgs = _addTrustedOrg(newTrustedOrg);

    address newAdmin = makeAddr("new-admin");
    address admin = makeAddr("candidate-admin");
    address newTreasury = makeAddr("new-treasury");
    address newConsensus = makeAddr("new-consensus");
    vm.startPrank(admin);
    _profile.requestChangeConsensusAddr(consensus, TConsensus.wrap(newConsensus));
    _profile.requestChangeTreasuryAddr(consensus, payable(newTreasury));
    _profile.requestChangeAdminAddress(consensus, newAdmin);
    vm.stopPrank();

    // change new governor
    address newGovernor = makeAddr("new-governor");
    trustedOrgs[0].governor = newGovernor;
    trustedOrgs[0].consensusAddr = TConsensus.wrap(newConsensus);
    vm.prank(_getProxyAdmin(address(_roninTO)));
    TransparentUpgradeableProxyV2(payable(address(_roninTO))).functionDelegateCall(
      abi.encodeCall(RoninTrustedOrganization.updateTrustedOrganizations, trustedOrgs)
    );

    IProfile.CandidateProfile memory profile = _profile.getId2Profile(consensus);
    IRoninTrustedOrganization.TrustedOrganization memory trustedOrg = _roninTO.getTrustedOrganization(
      TConsensus.wrap(newConsensus)
    );

    // assert eq to updated address
    assertEq(trustedOrg.governor, newGovernor);
    assertEq(TConsensus.unwrap(trustedOrg.consensusAddr), newConsensus);
    assertEq(profile.id, consensus);
    assertEq(profile.treasury, payable(newTreasury));
    assertEq(profile.__reservedGovernor, address(0x0));
    assertEq(TConsensus.unwrap(profile.consensus), newConsensus);

    // 2.
    __assertWeight(TConsensus.wrap(newConsensus), consensus, newWeight);
    __assertWeight(TConsensus.wrap(consensus), consensus, 0);
  }

  function __assertWeight(TConsensus consensus, address id, uint256 weight) private {
    TConsensus[] memory consensuses = new TConsensus[](1);
    address[] memory ids = new address[](1);

    consensuses[0] = consensus;
    ids[0] = id;

    if (weight == 0) {
      assertEq(_roninTO.getConsensusWeight(consensuses[0]), weight);
      assertEq(_roninTO.getConsensusWeight(consensuses[0]), _roninTO.getConsensusWeight(consensuses[0]));
    } else {
      assertEq(_roninTO.getConsensusWeight(consensuses[0]), weight);
      assertEq(_roninTO.getConsensusWeight(consensuses[0]), _roninTO.getConsensusWeights(consensuses)[0]);
      assertEq(_roninTO.getConsensusWeights(consensuses)[0], _roninTO.getConsensusWeightById(ids[0]));
      assertEq(_roninTO.getConsensusWeightById(ids[0]), _roninTO.getConsensusWeightsById(ids)[0]);
      assertEq(_roninTO.getConsensusWeightsById(ids)[0], _roninTO.getConsensusWeight(consensuses[0]));
    }
  }

  function testFork_AfterUpgraded_WithdrawableFund_execEmergencyExit() external upgrade {
    // TODO(bao): @TuDo1403 please enhance this test
    _cheatSetRoninGACode();
    IRoninTrustedOrganization.TrustedOrganization[] memory trustedOrgs = _roninTO.getAllTrustedOrganizations();
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[2];
    ICandidateManager.ValidatorCandidate memory oldCandidate = _validator.getCandidateInfo(
      TConsensus.wrap(validatorCandidate)
    );

    (address admin, , ) = _staking.getPoolDetail(TConsensus.wrap(validatorCandidate));

    address newAdmin = makeAddr("new-admin");
    address payable newTreasury = payable(makeAddr("new-treasury"));
    TConsensus newConsensusAddr = TConsensus.wrap(makeAddr("new-consensus"));

    uint256 proposalRequestAt = block.timestamp;
    uint256 proposalExpiredAt = proposalRequestAt + _validator.emergencyExpiryDuration();
    bytes32 voteHash = EmergencyExitBallot.hash(
      TConsensus.unwrap(oldCandidate.__shadowedConsensus),
      oldCandidate.__shadowedTreasury,
      proposalRequestAt,
      proposalExpiredAt
    );

    vm.startPrank(admin);
    vm.expectEmit(address(_roninGA));
    emit IRoninGovernanceAdmin.EmergencyExitPollCreated(
      voteHash,
      TConsensus.unwrap(oldCandidate.__shadowedConsensus),
      oldCandidate.__shadowedTreasury,
      proposalRequestAt,
      proposalExpiredAt
    );
    _staking.requestEmergencyExit(TConsensus.wrap(validatorCandidate));
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensusAddr);
    _profile.requestChangeTreasuryAddr(validatorCandidate, newTreasury);
    _profile.requestChangeAdminAddress(validatorCandidate, newAdmin);
    vm.stopPrank();

    // NOTE: locked fund refunded to the old treasury
    uint256 balanceBefore = oldCandidate.__shadowedTreasury.balance;

    for (uint256 i; i < trustedOrgs.length; ++i) {
      if (trustedOrgs[i].governor != validatorCandidate) {
        vm.prank(trustedOrgs[i].governor);
        _roninGA.voteEmergencyExit(
          voteHash,
          TConsensus.unwrap(oldCandidate.__shadowedConsensus),
          oldCandidate.__shadowedTreasury,
          proposalRequestAt,
          proposalExpiredAt
        );
      }
    }

    uint256 balanceAfter = oldCandidate.__shadowedTreasury.balance;
    uint256 fundReceived = balanceAfter - balanceBefore;

    assertTrue(fundReceived != 0);
  }

  function testFork_AsTrustedOrg_AfterUpgraded_AfterChangeConsensus_requestRenounce() external upgrade {
    TConsensus trustedOrg = _roninTO.getAllTrustedOrganizations()[0].consensusAddr;
    address admin = _validator.getCandidateInfo(trustedOrg).__shadowedAdmin;

    TConsensus newConsensus = TConsensus.wrap(makeAddr("new-consensus"));
    vm.prank(admin);
    _profile.requestChangeConsensusAddr(TConsensus.unwrap(trustedOrg), newConsensus);

    (address poolAdmin, , ) = _staking.getPoolDetail(newConsensus);

    vm.expectRevert();
    vm.prank(poolAdmin);
    _staking.requestRenounce(newConsensus);
  }

  function testFork_AsTrustedOrg_AfterUpgraded_AfterChangeConsensus_execEmergencyExit() external upgrade {
    TConsensus trustedOrg = _roninTO.getAllTrustedOrganizations()[0].consensusAddr;
    address admin = _validator.getCandidateInfo(trustedOrg).__shadowedAdmin;

    TConsensus newConsensus = TConsensus.wrap(makeAddr("new-consensus"));
    vm.prank(admin);
    _profile.requestChangeConsensusAddr(TConsensus.unwrap(trustedOrg), newConsensus);

    (address poolAdmin, , ) = _staking.getPoolDetail(newConsensus);

    vm.prank(poolAdmin);
    _staking.requestEmergencyExit(newConsensus);
  }

  function testFork_NotReceiveReward_BeforeAndAfterUpgraded_execEmergencyExit() external {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[2];
    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;

    uint256 snapshotId = vm.snapshot();

    (address admin, , ) = _staking.getPoolDetail(TConsensus.wrap(validatorCandidate));
    vm.prank(admin);
    _staking.requestEmergencyExit(TConsensus.wrap(validatorCandidate));

    uint256 adminBalanceBefore = admin.balance;

    vm.warp(block.timestamp + 7 days);
    _bulkWrapUpEpoch(1);

    uint256 adminBalanceAfter = admin.balance;

    assertFalse(_validator.isValidatorCandidate(TConsensus.wrap(validatorCandidate)));
    uint256 balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    uint256 balanceAfter = recipient.balance;
    uint256 rewardBeforeUpgrade = balanceAfter - balanceBefore;
    uint256 beforeUpgradeAdminStakingAmount = adminBalanceAfter - adminBalanceBefore;

    assertEq(rewardBeforeUpgrade, 0);

    vm.revertTo(snapshotId);
    _upgradeContracts();

    (admin, , ) = _staking.getPoolDetail(TConsensus.wrap(validatorCandidate));
    vm.prank(admin);
    _staking.requestEmergencyExit(TConsensus.wrap(validatorCandidate));

    adminBalanceBefore = admin.balance;

    vm.warp(block.timestamp + 7 days);
    _bulkWrapUpEpoch(1);

    adminBalanceAfter = admin.balance;

    uint256 afterUpgradeAdminStakingAmount = adminBalanceAfter - adminBalanceBefore;
    assertFalse(_validator.isValidatorCandidate(TConsensus.wrap(validatorCandidate)));
    balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    balanceAfter = recipient.balance;
    uint256 rewardAfterUpgrade = balanceAfter - balanceBefore;

    assertEq(rewardAfterUpgrade, 0);
    assertEq(beforeUpgradeAdminStakingAmount, afterUpgradeAdminStakingAmount);
  }

  function testFork_AfterUpgraded_RevertWhen_ReapplySameAddress_Renounce() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[2];
    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;

    (address admin, , ) = _staking.getPoolDetail(TConsensus.wrap(validatorCandidate));
    vm.prank(admin);
    _staking.requestRenounce(TConsensus.wrap(validatorCandidate));

    vm.warp(block.timestamp + 7 days);
    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    assertFalse(_validator.isValidatorCandidate(TConsensus.wrap(validatorCandidate)));

    // re-apply same admin
    uint256 amount = _staking.minValidatorStakingAmount();
    vm.deal(admin, amount);
    vm.expectRevert();
    vm.prank(admin);
    _staking.applyValidatorCandidate{ value: amount }(
      admin,
      TConsensus.wrap(makeAddr("new-consensus")),
      payable(admin),
      2500,
      "new-consensus"
    );
    // re-apply same consensus
    address newAdmin = makeAddr("new-admin");
    vm.deal(newAdmin, amount);
    vm.expectRevert();
    vm.prank(newAdmin);
    _staking.applyValidatorCandidate{ value: amount }(
      newAdmin,
      TConsensus.wrap(validatorCandidate),
      payable(newAdmin),
      2500,
      "new-admin"
    );

    uint256 balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    uint256 balanceAfter = recipient.balance;
    uint256 reward = balanceAfter - balanceBefore;

    assertEq(reward, 0);
  }

  function testFork_AfterUpgraded_ChangeConsensusAddress() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("new-consensus-0"));

    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkWrapUpEpoch(1);

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    newConsensus = TConsensus.wrap(makeAddr("new-consensus-1"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkWrapUpEpoch(1);
  }

  function testFork_AfterUpgraded_WrapUpEpochAndNonWrapUpEpoch_ChangeAdmin_ChangeConsensus_ChangeTreasury()
    external
    upgrade
  {
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
    _bulkWrapUpEpoch(1);

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
    assertEq(TConsensus.unwrap(mProfile.consensus), newConsensus);
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
    uint256 balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    _bulkSlashIndicator(validatorCandidate, 150);

    _bulkWrapUpEpoch(1);

    uint256 balanceAfter = recipient.balance;
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;
    assertFalse(_validator.isBlockProducer(TConsensus.wrap(validatorCandidate)));

    vm.revertTo(snapshotId);
    _upgradeContracts();
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkSubmitBlockReward(1);
    _bulkSlashIndicator(TConsensus.unwrap(newConsensus), 150);

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    balanceBefore = recipient.balance;

    _bulkWrapUpEpoch(1);

    balanceAfter = recipient.balance;
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;

    assertFalse(_validator.isBlockProducer(newConsensus));
    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
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
    uint256 balanceBefore = recipient.balance;
    uint256 minOffsetToStartSchedule = _maintenance.minOffsetToStartSchedule();

    // save snapshot state before wrapup
    uint256 snapshotId = vm.snapshot();

    _bulkSubmitBlockReward(1);
    uint256 latestEpoch = _validator.getLastUpdatedBlock() + 200;
    uint256 startMaintenanceBlock = latestEpoch + 1 + minOffsetToStartSchedule;
    uint256 endMaintenanceBlock = latestEpoch + minOffsetToStartSchedule + _maintenance.minMaintenanceDurationInBlock();
    this.schedule(candidateAdmin, validatorCandidate, startMaintenanceBlock, endMaintenanceBlock);
    vm.roll(latestEpoch + minOffsetToStartSchedule + 200);

    _bulkSlashIndicator(validatorCandidate, 150);
    _bulkWrapUpEpoch(1);

    // assertFalse(_maintenance.checkMaintained(TConsensus.wrap(validatorCandidate), block.number + 1));
    assertFalse(_validator.isBlockProducer(TConsensus.wrap(validatorCandidate)));
    uint256 balanceAfter = recipient.balance;
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;

    // revert to previous state
    vm.revertTo(snapshotId);
    _upgradeContracts();
    // change consensus address
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    latestEpoch = _validator.getLastUpdatedBlock() + 200;
    startMaintenanceBlock = latestEpoch + 1 + minOffsetToStartSchedule;
    endMaintenanceBlock = latestEpoch + minOffsetToStartSchedule + _maintenance.minMaintenanceDurationInBlock();

    this.schedule(candidateAdmin, TConsensus.unwrap(newConsensus), startMaintenanceBlock, endMaintenanceBlock);
    vm.roll(latestEpoch + minOffsetToStartSchedule + 200);

    _bulkSlashIndicator(TConsensus.unwrap(newConsensus), 150);
    _bulkWrapUpEpoch(1);

    assertFalse(_maintenance.checkMaintained(TConsensus.wrap(validatorCandidate), block.number + 1));
    assertFalse(_validator.isBlockProducer(newConsensus));
    balanceAfter = recipient.balance;
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;
    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
  }

  function testFork_ShareSameSameReward_BeforeAndAfterUpgrade() external {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    //address recipient = candidateAdmin;
    address recipient = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedTreasury;
    uint256 balanceBefore = recipient.balance;
    uint256 snapshotId = vm.snapshot();

    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    uint256 balanceAfter = recipient.balance;
    uint256 beforeUpgradeReward = balanceAfter - balanceBefore;

    vm.revertTo(snapshotId);
    _upgradeContracts();
    TConsensus newConsensus = TConsensus.wrap(makeAddr("consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    recipient = _validator.getCandidateInfo(newConsensus).__shadowedTreasury;
    balanceBefore = recipient.balance;

    _bulkSubmitBlockReward(1);
    _bulkWrapUpEpoch(1);

    balanceAfter = recipient.balance;
    uint256 afterUpgradedReward = balanceAfter - balanceBefore;

    assertEq(afterUpgradedReward, beforeUpgradeReward, "afterUpgradedReward != beforeUpgradeReward");
  }

  function testFailFork_RevertWhen_AfterUpgraded_DifferentAdmins_ShareSameConsensusAddr() external upgrade {
    address[] memory validatorCandidates = _validator.getValidatorCandidates();
    address validatorCandidate = validatorCandidates[0];
    address candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    TConsensus newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkWrapUpEpoch(1);

    validatorCandidate = validatorCandidates[1];
    candidateAdmin = _validator.getCandidateInfo(TConsensus.wrap(validatorCandidate)).__shadowedAdmin;
    newConsensus = TConsensus.wrap(makeAddr("same-consensus"));
    vm.prank(candidateAdmin);
    _profile.requestChangeConsensusAddr(validatorCandidate, newConsensus);

    _bulkWrapUpEpoch(1);
  }

  function testFork_AfterUpgraded_applyValidatorCandidate() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");
    _applyValidatorCandidate("candidate-admin-1", "consensus-1");
    _bulkWrapUpEpoch(1);
  }

  function testFork_AfterUpgraded_applyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin-0", "consensus-0");
    _bulkWrapUpEpoch(1);
    _applyValidatorCandidate("candidate-admin-1", "consensus-1");
  }

  function testFailFork_RevertWhen_AfterUpgraded_ReapplyValidatorCandidateByPeriod() external upgrade {
    _applyValidatorCandidate("candidate-admin", "consensus");
    _bulkWrapUpEpoch(1);
    _applyValidatorCandidate("candidate-admin", "consensus");
  }

  function testFailFork_RevertWhen_AfterUpgraded_ReapplyValidatorCandidate() external upgrade {
    _applyValidatorCandidate("candidate-admin", "consensus");
    _applyValidatorCandidate("candidate-admin", "consensus");
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

  function _bulkSlashIndicator(address consensus, uint256 times) internal {
    vm.startPrank(block.coinbase);
    for (uint256 i; i < times; ++i) {
      _slashIndicator.slashUnavailability(TConsensus.wrap(consensus));
      vm.roll(block.number + 1);
    }
    vm.stopPrank();
  }

  function _bulkSubmitBlockReward(uint256 times) internal {
    for (uint256 i; i < times; ++i) {
      vm.roll(block.number + 1);
      vm.deal(block.coinbase, 1000 ether);
      vm.prank(block.coinbase);
      _validator.submitBlockReward{ value: 1000 ether }();
    }
  }

  function _upgradeProfile() internal {
    Profile logic = new Profile();
    vm.prank(_getProxyAdmin(address(_profile)));
    TransparentUpgradeableProxyV2(payable(address(_profile))).upgradeToAndCall(
      address(logic),
      abi.encodeCall(Profile.initializeV2, address(_staking))
    );
    _profile.initializeV3(address(_roninTO));
  }

  function _cheatSetRoninGACode() internal {
    RoninGovernanceAdmin logic = new RoninGovernanceAdmin(
      block.chainid,
      address(_roninTO),
      address(_validator),
      type(uint256).max
    );
    vm.etch(address(_roninGA), address(logic).code);

    vm.startPrank(address(_roninGA));
    _roninGA.setContract(ContractType.VALIDATOR, address(_validator));
    _roninGA.setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, address(_roninTO));
    vm.stopPrank();
  }

  function _upgradeMaintenance() internal {
    Maintenance logic = new Maintenance();
    vm.prank(_getProxyAdmin(address(_maintenance)));
    TransparentUpgradeableProxyV2(payable(address(_maintenance))).upgradeToAndCall(
      address(logic),
      abi.encodeCall(Maintenance.initializeV3, (address(_profile)))
    );
  }

  function _upgradeRoninTO() internal {
    RoninTrustedOrganization logic = new RoninTrustedOrganization();
    vm.prank(_getProxyAdmin(address(_roninTO)));
    TransparentUpgradeableProxyV2(payable(address(_roninTO))).upgradeToAndCall(
      address(logic),
      abi.encodeCall(RoninTrustedOrganization.initializeV2, (address(_profile)))
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

  function _addTrustedOrg(
    IRoninTrustedOrganization.TrustedOrganization memory trustedOrg
  ) internal returns (IRoninTrustedOrganization.TrustedOrganization[] memory trustedOrgs) {
    trustedOrgs = new IRoninTrustedOrganization.TrustedOrganization[](1);
    trustedOrgs[0] = trustedOrg;
    vm.prank(_getProxyAdmin(address(_roninTO)));
    TransparentUpgradeableProxyV2(payable(address(_roninTO))).functionDelegateCall(
      abi.encodeCall(RoninTrustedOrganization.addTrustedOrganizations, trustedOrgs)
    );
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
      15_00,
      pubKey
    );
  }
}