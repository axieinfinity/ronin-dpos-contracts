// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILogicValidatorSet, MockLogicValidatorSetV1, MockLogicValidatorSetV2 } from "@ronin/contracts/mocks/utils/version-control/MockLogicValidatorSet.sol";
import { NotifiedMigrator } from "@ronin/contracts/ronin/validator/migrations/NotifiedMigrator.sol";
import { RoninValidatorSetTimedMigrator } from "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";
import { MockActor, MockLogicV1, MockLogicV2, IConditionalImplementControl, AddressArrayUtils, ConditionalImplementControlTest, TransparentUpgradeableProxyV2 } from "./ConditionalVersionControl.t.sol";
import { IHasContracts } from "@ronin/contracts/interfaces/collections/IHasContracts.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";

contract RoninValidatorSetTimedMigratorTest is ConditionalImplementControlTest {
  event Received(string version);

  address internal _stakingProxy;
  address internal _slashIndicatorProxy;
  address internal _roninTrustedOrgProxy;

  function _setUp() internal override {
    _proxyAdmin = vm.addr(1);

    _oldImpl = address(new MockLogicValidatorSetV1());
    _newImpl = address(new MockLogicValidatorSetV2());

    _upgradedAtBlock = 100;
    _proxy = payable(address(new TransparentUpgradeableProxyV2(_oldImpl, _proxyAdmin, "")));
    _switcher = payable(address(new RoninValidatorSetTimedMigrator(_proxy, _oldImpl, _newImpl)));
    _contractCaller = new MockActor(_proxy);

    address stakingLogicV1 = address(new MockLogicV1());
    address stakingLogicV2 = address(new MockLogicV2());
    _stakingProxy = address(new TransparentUpgradeableProxyV2(stakingLogicV1, _proxyAdmin, ""));
    address stakingSwitcher = address(new NotifiedMigrator(_stakingProxy, stakingLogicV1, stakingLogicV2, _proxy));
    vm.prank(_proxyAdmin, _proxyAdmin);
    TransparentUpgradeableProxyV2(payable(_stakingProxy)).upgradeTo(stakingSwitcher);

    address slashIndicatorLogicV1 = address(new MockLogicV1());
    address slashIndicatorLogicV2 = address(new MockLogicV2());
    _slashIndicatorProxy = address(new TransparentUpgradeableProxyV2(slashIndicatorLogicV1, _proxyAdmin, ""));
    address slashIndicatorSwitcher = address(
      new NotifiedMigrator(_slashIndicatorProxy, slashIndicatorLogicV1, slashIndicatorLogicV2, _proxy)
    );
    vm.prank(_proxyAdmin, _proxyAdmin);
    TransparentUpgradeableProxyV2(payable(_slashIndicatorProxy)).upgradeTo(slashIndicatorSwitcher);

    address roninTrustedOrgLogicV1 = address(new MockLogicV1());
    address roninTrustedOrgLogicV2 = address(new MockLogicV2());
    _roninTrustedOrgProxy = address(new TransparentUpgradeableProxyV2(roninTrustedOrgLogicV1, _proxyAdmin, ""));
    address roninTrustedOrgSwitcher = address(
      new NotifiedMigrator(_roninTrustedOrgProxy, roninTrustedOrgLogicV1, roninTrustedOrgLogicV2, _proxy)
    );

    vm.prank(_proxyAdmin, _proxyAdmin);
    TransparentUpgradeableProxyV2(payable(_roninTrustedOrgProxy)).upgradeTo(roninTrustedOrgSwitcher);
  }

  function _manualUpgradeTo(address impl) internal virtual override {
    super._manualUpgradeTo(impl);

    vm.startPrank(_proxyAdmin, _proxyAdmin);
    TransparentUpgradeableProxyV2(payable(_proxy)).functionDelegateCall(
      abi.encodeCall(IHasContracts.setContract, (ContractType.STAKING, _stakingProxy))
    );
    TransparentUpgradeableProxyV2(payable(_proxy)).functionDelegateCall(
      abi.encodeCall(IHasContracts.setContract, (ContractType.SLASH_INDICATOR, _slashIndicatorProxy))
    );
    TransparentUpgradeableProxyV2(payable(_proxy)).functionDelegateCall(
      abi.encodeCall(IHasContracts.setContract, (ContractType.RONIN_TRUSTED_ORGANIZATION, _roninTrustedOrgProxy))
    );

    vm.stopPrank();
  }

  /**
   * @notice Checks before upgrading.
   */
  function test_BeforeUpgrading() public override {
    assertEq(ILogicValidatorSet(_proxy).currentPeriod(), 0);
  }

  /**
   * @notice Checks whether the delegate calls are still to the old implementation contract after upgrading to the
   * contract switcher.
   */
  function test_AfterUsingContractSwitcher_DelegateCall_OldImpl() public override {
    test_BeforeUpgrading();
    _manualUpgradeTo(_switcher);
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
  }

  /**
   * @notice Checks whether the delegate calls are to the new implementation contract after upgrading to the contract
   * switcher and the switch condition is met.
   */
  function test_AfterUsingContractSwitcher_DelegateCall_NewImpl() external override {
    vm.skip(true);
    test_AfterUsingContractSwitcher_DelegateCall_OldImpl();
    vm.roll(_upgradedAtBlock);
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_newImpl).version());
  }

  /**
   * @notice Checks whether the proxy can receive native token using old implemenation after upgrading to the contract
   * switcher.
   */
  function test_AfterUsingContractSwitcher_ReceiveNativeToken_OldImpl(address user, uint256 amount) external override {
    vm.assume(amount > 0 && user != _proxyAdmin);
    vm.deal(user, amount);
    _manualUpgradeTo(_switcher);

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_oldImpl).version());
    vm.prank(user);
    (bool ok, ) = _proxy.call{ value: amount }("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }

  /**
   * @notice Checks whether the proxy can receive native token using new implemenation after upgrading to the contract
   * switcher.
   */
  function test_AfterUsingContractSwitcher_ReceiveNativeToken_NewImpl(address user, uint256 amount) external override {
    vm.skip(true);
    vm.assume(amount > 0 && user != _proxyAdmin);
    vm.deal(user, amount);
    _manualUpgradeTo(_switcher);
    vm.roll(_upgradedAtBlock);

    emit Received(ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_newImpl).version());
    vm.prank(user);
    (bool ok, ) = _proxy.call{ value: amount }("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }

  /**
   * @dev Creates a new conditional implement control for testing purposes.
   */
  function _createConditionalImplementControl(address[3] memory inputs) internal override returns (address) {
    return address(new RoninValidatorSetTimedMigrator(inputs[0], inputs[1], inputs[2]));
  }
}
