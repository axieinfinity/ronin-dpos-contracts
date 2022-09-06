// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../libraries/Sorting.sol";
import "./StakingManager.sol";

contract DPoStaking is IStaking, StakingManager, Initializable {
  /// @dev The minimum threshold for being a validator candidate.
  uint256 internal _minValidatorBalance;
  /// @dev Maximum number of validator.
  uint256 internal _maxValidatorCandidate;
  /// @dev Governance admin contract address.
  address internal _governanceAdminContract; // TODO(Thor): add setter.
  /// @dev Validator contract address.
  address internal _validatorContract; // Change type to address for testing purpose

  /// @dev Mapping from consensus address => bitwise negation of validator index in `validatorCandidates`.
  mapping(address => uint256) internal _candidateIndex;
  /// @dev The validator candidate array.
  ValidatorCandidate[] public validatorCandidates;
  /// @dev Mapping from consensus address => period index => indicating the pending reward in the period is sinked or not.
  mapping(address => mapping(uint256 => bool)) internal _pRewardSinked;

  modifier onlyGovernanceAdminContract() {
    require(msg.sender == _governanceAdminContract, "DPoStaking: method caller is not governance admin contract");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == _validatorContract, "DPoStaking: method caller is not the validator contract");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  receive() external payable onlyValidatorContract {}

  fallback() external payable onlyValidatorContract {}

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    address __governanceAdminContract,
    uint256 __maxValidatorCandidate,
    uint256 __minValidatorBalance
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setGovernanceAdminContractAddress(__governanceAdminContract);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setMinValidatorBalance(__minValidatorBalance);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function governanceAdminContract() public view override returns (address) {
    return _governanceAdminContract;
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorBalance() public view override(IStaking, StakingManager) returns (uint256) {
    return _minValidatorBalance;
  }

  /**
   * @inheritdoc IStaking
   */
  function setMinValidatorBalance(uint256 _threshold) external onlyGovernanceAdminContract {
    _setMinValidatorBalance(_threshold);
  }

  /**
   * @inheritdoc IStaking
   */
  function maxValidatorCandidate() public view override(IStaking, StakingManager) returns (uint256) {
    return _maxValidatorCandidate;
  }

  /**
   * @inheritdoc IStaking
   */
  function setMaxValidatorCandidate(uint256 _threshold) external onlyGovernanceAdminContract {
    _setMaxValidatorCandidate(_threshold);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR VALIDATOR                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function getValidatorCandidates() public view returns (ValidatorCandidate[] memory) {
    return validatorCandidates;
  }

  /**
   * @inheritdoc IStaking
   */
  function getCandidateWeights() external view returns (address[] memory _candidates, uint256[] memory _weights) {
    uint256 _length = validatorCandidates.length;
    _candidates = new address[](_length);
    _weights = new uint256[](_length);
    for (uint256 _i; _i < _length; _i++) {
      ValidatorCandidate storage _candidate = validatorCandidates[_i];
      _candidates[_i] = _candidate.consensusAddr;
      _weights[_i] = _candidate.delegatedAmount;
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function recordReward(address _consensusAddr, uint256 _reward) external payable onlyValidatorContract {
    _recordReward(_consensusAddr, _reward);
  }

  /**
   * @inheritdoc IStaking
   */
  function settleRewardPool(address _consensusAddr) external onlyValidatorContract {
    _onPoolSettled(_consensusAddr);
  }

  /**
   * @inheritdoc IStaking
   */
  function settleMultipleRewardPools(address[] calldata _consensusAddrs) external onlyValidatorContract {
    for (uint _i = 0; _i < _consensusAddrs.length; _i++) {
      _onPoolSettled(_consensusAddrs[_i]);
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function sinkPendingReward(address _consensusAddr) external {
    uint256 _period = _periodOf(block.number);
    _pRewardSinked[_consensusAddr][_period] = true;
    _sinkPendingReward(_consensusAddr);
  }

  /**
   * @inheritdoc IStaking
   */
  function deductStakingAmount(address _consensusAddr, uint256 _amount) external onlyValidatorContract {
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    _unstake(_consensusAddr, _candidate.candidateAdmin, _amount);
    _undelegate(_consensusAddr, _candidate.candidateAdmin, _amount);
  }

  /**
   * @inheritdoc IStaking
   */
  function commissionRateOf(address _consensusAddr) external view returns (uint256 _rate) {
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    return _candidate.commissionRate;
  }

  /**
   * @inheritdoc IStaking
   */
  function treasuryAddressOf(address _consensusAddr) external view returns (address) {
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    return _candidate.treasuryAddr;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  HELPER FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc StakingManager
   */
  function _getCandidate(address _consensusAddr)
    internal
    view
    override
    returns (ValidatorCandidate storage _candidate)
  {
    uint256 _idx = _candidateIndex[_consensusAddr];
    require(_idx > 0, "DPoStaking: query for nonexistent candidate");
    _candidate = validatorCandidates[~_idx];
  }

  /**
   * @inheritdoc StakingManager
   */
  function _getCandidateIndex(address _consensusAddr) internal view override returns (uint256) {
    return _candidateIndex[_consensusAddr];
  }

  /**
   * @inheritdoc StakingManager
   */
  function _setCandidateIndex(address _consensusAddr, uint256 _candidateIdx) internal override {
    _candidateIndex[_consensusAddr] = _candidateIdx;
  }

  /**
   * @inheritdoc StakingManager
   */
  function _getValidatorCandidateLength() internal view override returns (uint256) {
    return validatorCandidates.length;
  }

  /**
   * @dev Sets the governance admin contract address.
   *
   * Emits the `GovernanceAdminContractUpdated` event.
   *
   */
  function _setGovernanceAdminContractAddress(address _newAddr) internal {
    _governanceAdminContract = _newAddr;
    emit GovernanceAdminContractUpdated(_newAddr);
  }

  /**
   * @dev Sets the governance admin contract address.
   *
   * Emits the `ValidatorContractUpdated` event.
   *
   */
  function _setValidatorContract(address _newValidatorContract) internal {
    _validatorContract = _newValidatorContract;
    emit ValidatorContractUpdated(_newValidatorContract);
  }

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Emits the `MinValidatorBalanceUpdated` event.
   *
   */
  function _setMinValidatorBalance(uint256 _threshold) internal {
    _minValidatorBalance = _threshold;
    emit MinValidatorBalanceUpdated(_threshold);
  }

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Requirements:
   * - The method caller is governance admin.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function _setMaxValidatorCandidate(uint256 _threshold) internal {
    _maxValidatorCandidate = _threshold;
    emit MaxValidatorCandidateUpdated(_threshold);
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _rewardSinked(address _poolAddr, uint256 _period) internal view virtual override returns (bool) {
    return _pRewardSinked[_poolAddr][_period];
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _periodOf(uint256 _block) internal view virtual override returns (uint256) {
    return IValidatorSet(_validatorContract).periodOf(_block);
  }

  /**
   * @inheritdoc StakingManager
   */
  function _createValidatorCandidate(
    address _consensusAddr,
    address _candidateOwner,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) internal virtual override returns (ValidatorCandidate memory) {
    ValidatorCandidate storage _candidate = validatorCandidates.push();
    _candidate.consensusAddr = _consensusAddr;
    _candidate.candidateAdmin = _candidateOwner;
    _candidate.treasuryAddr = _treasuryAddr;
    _candidate.commissionRate = _commissionRate;
    return _candidate;
  }
}
