// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../libraries/Sorting.sol";
import "hardhat/console.sol";

contract Staking is IStaking, Initializable {
  /// TODO: expose fn to get validator info by validator address.
  /// @dev Mapping from consensus address => validator index in `validatorCandidates`.
  mapping(address => uint256) internal _validatorIndexes;
  /// TODO: expose fn returns the whole validator array.
  /// @dev Validator array. The order of the validator is assured not to be changed, since this
  /// array is kept synced with the array in the `Staking` contract. The element at 0-index is
  /// always an empty validator.
  ValidatorCandidate[] public validatorCandidates;

  /// @dev Index of validators that are mining in the current epoch. Get updated each epoch.
  /// Element at 0-index is always `0`.
  uint256[] internal _currentValidatorIndexes;

  /// @dev Index of validators that are on renounce
  uint256[] internal _pendingRenouncingValidatorIndexes;

  /// @dev Mapping from delegator address => consensus address => delegated amount.
  mapping(address => mapping(address => uint256)) delegatedAmount;

  // TODO: expose this fn in the interface
  /// @dev Configuration of maximum number of validator
  uint256 public totalValidatorThreshold;

  // TODO: expose this fn in the interface
  /// @dev Configuration of number of blocks that validator has to wait before unstaking, counted
  /// from staking time
  uint256 public unstakingOnHoldBlocksNum;

  // TODO: expose this fn in the interface
  /// @dev Configuration of minimum balance for being a validator
  uint256 public minValidatorBalance;

  /// @dev Number of maximum working validator in one epoch
  uint256 public numOfCabinets;

  /// @dev Validator contract address
  IValidatorSet public validatorSetContract;

  /// @dev Helper global flag which is set to true on at least one validator balance changes, and
  /// is reset to false per epoch. This help reduces redundant sortings.
  bool internal _globalBalanceChanged;

  modifier onlyValidatorSetContract() {
    require(msg.sender == address(validatorSetContract), "Only validator set contract");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize() external initializer {
    /// TODO: bring these constant variable to params.
    numOfCabinets = 21;
    totalValidatorThreshold = 50;
    unstakingOnHoldBlocksNum = 28800; // 28800 blocks ~= 1 day
    minValidatorBalance = 3 * 1e6 * 1e18; // 3m RON
    /// Add empty validator at 0-index
    validatorCandidates.push();
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  // TODO: restrict to only govenance
  function setValidatorSetContract(IValidatorSet _validatorSetContract) external {
    validatorSetContract = _validatorSetContract;
  }

  // TODO: restrict to only govenance
  function setNumOfCabinets(uint256 _numOfCabinets) external {
    numOfCabinets = _numOfCabinets;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR VALIDATORS                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev See {IStaking-proposeValidator}.
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable returns (uint256 _candidateIdx) {
    uint256 _amount = msg.value;
    address _stakingAddr = msg.sender;

    require(validatorCandidates.length < totalValidatorThreshold, "Staking: query for exceeded validator array length");
    require(_amount >= minValidatorBalance, "Staking: insuficient amount");
    require(_treasuryAddr != address(0), "Staking: invalid treasury address");

    ValidatorCandidate storage _candidate;
    if (_validatorIndexes[_consensusAddr] > 0) {
      /// renounced validator joins as a validator again
      (, _candidate) = _getDeprecatedCandidate(_consensusAddr);
      require(_candidate.state == ValidatorState.RENOUNCED, "Staking: cannot propose an existed candidate");
      _candidate.state = ValidatorState.ACTIVE;
    } else {
      /// totally new validator joins
      _candidateIdx = validatorCandidates.length;
      _candidate = validatorCandidates.push();
      _validatorIndexes[_consensusAddr] = _candidateIdx;
      _candidate.consensusAddr = _consensusAddr;
    }

    _candidate.candidateAdmin = _stakingAddr;
    _candidate.treasuryAddr = _treasuryAddr;
    _candidate.commissionRate = _commissionRate;
    _candidate.stakedAmount = _amount;

    _globalBalanceChanged = true;

    emit ValidatorProposed(_consensusAddr, _stakingAddr, _amount, _candidate);
  }

  /**
   * @dev See {IStaking-stake}.
   */
  function stake(address _consensusAddr) external payable {
    uint256 _amount = msg.value;
    (, ValidatorCandidate storage _candidate) = _getCandidate(_consensusAddr);
    console.log("[*] Staking");
    console.log("[ ] \t stake address:\t", _candidate.candidateAdmin);
    console.log("[ ] \t consensus address:\t", _candidate.consensusAddr);
    require(_candidate.candidateAdmin == msg.sender, "Staking: invalid staking address");

    _candidate.stakedAmount += _amount;

    _globalBalanceChanged = true;

    emit Staked(_consensusAddr, _amount);
  }

  /**
   * @dev See {IStaking-unstake}.
   */
  function unstake(address _consensusAddr, uint256 _amount) external {
    (, ValidatorCandidate storage _candidate) = _getCandidate(_consensusAddr);
    require(_candidate.candidateAdmin == msg.sender, "Staking: caller must be staking address");
    uint256 _maxUnstake = _candidate.stakedAmount - minValidatorBalance;
    require(_amount <= _maxUnstake, "Staking: invalid staked amount left");

    _candidate.stakedAmount -= _amount;
    _transferRON(msg.sender, _amount);

    _globalBalanceChanged = true;

    emit Unstaked(_consensusAddr, _amount);
  }

  /**
   * @notice Allow validator sends renouncing request. The request gets affected when the epoch ends.
   *
   * @dev The following procedure must be done in multiple methods in order to finish the renounce.
   *
   * 1. This method:
   *    - Set `ValidatorState` of validator to `ON_REQUESTING_RENOUNCE`;
   *    - Push the validator to a pending list;
   *    - Trigger the `_globalBalanceChanged` flag.
   *
   * 2. The `updateValidatorSet` method:
   *    - Set `ValidatorState` of validator to `ON_CONFIRMED_RENOUNCE`;
   *    - Set the balance-to-sort of the validator to `0`;
   *    - Reset the `_globalBalanceChanged`s flag.
   *
   * 3. The `finalizeRenouncingValidator` method:
   *    - Remove validator from pending list
   *    - Set `ValidatorState` of validator to `RENOUNCED`;
   *    - Set `stakedAmount` of validator to `0`;
   *    - Transfer the staked to the respective staking address.
   *
   * Requirements:
   * - The validator must be exist
   * - The validator must be in `ACTIVE` state
   *
   */
  function requestRenouncingValidator(address _consensusAddr) external {
    (uint256 _index, ValidatorCandidate storage _candidate) = _getCandidate(_consensusAddr);
    require(_candidate.candidateAdmin == msg.sender, "Staking: caller must be staking address");

    console.log("[*] requestRenouncingValidator");
    console.log("[ ] \t index", _index);

    _candidate.state = ValidatorState.ON_REQUESTING_RENOUNCE;
    _pendingRenouncingValidatorIndexes.push(_index);

    _globalBalanceChanged = true;

    emit ValidatorRenounceRequested(_consensusAddr, _candidate.stakedAmount);
  }

  /**
   * @notice Allow validator finalizes renouncing request.
   *
   * @dev For the logic of this method, refer to {IStaking-requestRenouncingValidator}
   *
   * Requirements:
   * - The validator must be exist
   * - The validator must submitted renouncing request, and be `ON_CONFIRMED_RENOUNCE` state
   */
  function finalizeRenouncingValidator(address _consensusAddr) external {
    (uint256 _index, ValidatorCandidate storage _candidate) = _getDeprecatedCandidate(_consensusAddr);
    require(_candidate.candidateAdmin == msg.sender, "Staking: caller must be staking address");
    require(
      _candidate.state == ValidatorState.ON_CONFIRMED_RENOUNCE,
      "Staking: validator state is not ON_CONFIRMED_RENOUNCE"
    );

    bool _found;
    uint _length = _pendingRenouncingValidatorIndexes.length;
    uint _amount = _candidate.stakedAmount;
    for (uint i; i < _length; ++i) {
      if (_index == _pendingRenouncingValidatorIndexes[i]) {
        _found = true;
        _pendingRenouncingValidatorIndexes[i] = _pendingRenouncingValidatorIndexes[_length - 1];
        _pendingRenouncingValidatorIndexes.pop();
        break;
      }
    }
    require(_found, "Staking: cannot finalize not requested renounce");

    _candidate.state = ValidatorState.RENOUNCED;
    _candidate.stakedAmount = 0;
    _transferRON(msg.sender, _amount);

    emit ValidatorRenounceFinalized(_consensusAddr, _amount);
  }

  /**
   * @dev See {IStaking-delegate}.
   */
  function delegate(address _consensusAddr) public payable {
    _delegate(msg.sender, _consensusAddr, msg.value);
  }

  /**
   * @dev See {IStaking-delegate}.
   */
  function undelegate(address _consensusAddr, uint256 _amount) public {
    _undelegate(msg.sender, _consensusAddr, _amount);
    _transferRON(msg.sender, _amount);
  }

  /**
   * @dev TODO: move to IStaking.sol
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external {
    _undelegate(msg.sender, _consensusAddrSrc, _amount);
    _delegate(msg.sender, _consensusAddrDst, _amount);
  }

  /**
   * @dev TODO
   */
  function getRewards(address[] calldata _consensusAddrList)
    external
    view
    returns (uint256[] memory _pending, uint256[] memory _claimable)
  {
    revert("Unimplemented");
  }

  /**
   * @dev Claims rewards.
   */
  function claimRewards(address[] calldata _consensusAddrList, uint256 _amounts) external returns (uint256 _amount) {
    revert("Unimplemented");
  }

  /**
   * @dev Claims all pending rewards and delegates them to the consensus address.
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    returns (uint256 _amount)
  {
    revert("Unimplemented");
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Requirements:
   * - The validator is an existed candidate.
   *
   * Emits the `Delegated` event.
   *
   * @notice This function does not verify the `msg.value` with the amount.
   */
  function _delegate(
    address _delegator,
    address _consensusAddr,
    uint256 _amount
  ) internal {
    (, ValidatorCandidate storage _candidate) = _getCandidate(_consensusAddr);
    _candidate.delegatedAmount += _amount;
    delegatedAmount[_delegator][_consensusAddr] += _amount;

    emit Delegated(_delegator, _consensusAddr, _amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The validator is an existed candidate.
   * - The delegated amount is larger than or equal to the undelegated amount.
   *
   * Emits the `Undelegated` event.
   *
   * @notice Consider transferring back the amount of RON after calling this function.
   */
  function _undelegate(
    address _delegator,
    address _consensusAddr,
    uint256 _amount
  ) internal {
    require(delegatedAmount[_delegator][_consensusAddr] >= _amount, "Staking: insufficient amount to undelegate");

    (, ValidatorCandidate storage _candidate) = _getDeprecatedCandidate(_consensusAddr);
    _candidate.delegatedAmount -= _amount;
    delegatedAmount[_delegator][_consensusAddr] -= _amount;

    emit Undelegated(_delegator, _consensusAddr, _amount);
  }

  /**
   * @dev Returns the active validator candidate from storage.
   *
   * Requirements:
   * - The candidate is already existed.
   * - The candidate is in ACTIVE state
   *
   */
  function _getCandidate(address _consensusAddr)
    internal
    view
    returns (uint256 index_, ValidatorCandidate storage candidate_)
  {
    (index_, candidate_) = _getDeprecatedCandidate(_consensusAddr);
    require(candidate_.state == ValidatorState.ACTIVE, "Staking: query for deprecated candidate");
  }

  /**
   * @dev Returns the validator candidate from storage, without checking his status.
   *
   * Requirements:
   * - The candidate is already existed.
   *
   */
  function _getDeprecatedCandidate(address _consensusAddr)
    internal
    view
    returns (uint256 index_, ValidatorCandidate storage candidate_)
  {
    index_ = _validatorIndexes[_consensusAddr];
    require(index_ > 0, "Staking: query for nonexistent candidate");
    console.log("[*] _getCandidate");
    console.log("[ ] \t consensus address:\t", _consensusAddr);
    console.log("[ ] \t index:\t", index_);
    candidate_ = validatorCandidates[index_];
  }

  function _transferRON(address _to, uint256 _amount) private {
    // Using `call` to remove 2300 gas stipend
    // https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/
    (bool _success, ) = _to.call{ value: _amount }("");
    require(_success, "Staking: transfer RON failed");
  }

  /**
   * @notice Update set of validators
   *
   * @dev Sorting the validators by their current balance, then pick the top N validators to be
   * assigned to the new set. The result is returned to the `ValidatorSet` contract.
   *
   * Requirements:
   * - Only `ValidatorSet` contract can call this function
   *
   * @return newValidatorSet Validator set for the new epoch
   */
  function updateValidatorSet() external onlyValidatorSetContract returns (address[] memory newValidatorSet) {
    console.log("[ ] \t 1. gas left", gasleft());
    /// checking global state, skipping sorting if unchanged
    console.log("[*] updateValidatorSet");
    if (!_globalBalanceChanged) {
      console.log("[ ] \t skipped");
      return getCurrentValidatorSet();
    }

    console.log("[ ] \t sorted");
    _globalBalanceChanged = false;

    /// update renouncing status
    for (uint i = 0; i < _pendingRenouncingValidatorIndexes.length; ++i) {
      console.log("[ ] \t updating renouncing", i, _pendingRenouncingValidatorIndexes[i]);
      ValidatorCandidate storage _renouncingValidator = validatorCandidates[_pendingRenouncingValidatorIndexes[i]];
      _renouncingValidator.state = ValidatorState.ON_CONFIRMED_RENOUNCE;
    }

    /// prepare sorting data
    uint _length = validatorCandidates.length;
    uint _numOfActiveNodes = 0;
    Sorting.Node[] memory _nodes = new Sorting.Node[](_length);
    Sorting.Node[] memory _sortedNodes = new Sorting.Node[](_length);

    console.log("[ ] \t prepare data");
    _nodes[0] = Sorting.Node(0, type(uint256).max);
    for (uint i = 1; i < _length; i++) {
      ValidatorCandidate storage _candidate = validatorCandidates[i];
      _nodes[i].key = i;
      if (_candidate.state == ValidatorState.ACTIVE) {
        _nodes[i].value = _candidate.stakedAmount + _candidate.delegatedAmount;
        _numOfActiveNodes++;
      }
      console.log("[ ] \t\t key, value \t\t", _nodes[i].key, "\t", _nodes[i].value);
    }

    console.log("[ ] \t 3. gas left", gasleft());
    /// do sort
    _sortedNodes = Sorting.sortNodes(_nodes);

    console.log("[ ] \t 4. gas left", gasleft());

    /// TODO(bao): pick M validators which are governance
    uint _currentSetSize = (_numOfActiveNodes < numOfCabinets) ? (_numOfActiveNodes + 1) : (numOfCabinets + 1);
    console.log("[ ] \t after sort");
    console.log("[ ] \t\t _currentSetSize", _currentSetSize);
    delete _currentValidatorIndexes;
    for (uint i = 0; i < _currentSetSize; i++) {
      console.log("[ ] \t\t key, value \t\t", _sortedNodes[i].key, "\t", _sortedNodes[i].value);
      _currentValidatorIndexes.push(_sortedNodes[i].key);
    }

    console.log("[ ] \t 5. gas left", gasleft());

    return getCurrentValidatorSet();
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR QUERYING                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  function getCurrentValidatorSet() public view returns (address[] memory currentValidatorSet_) {
    console.log("[*] getPendingRenouncingValidatorIndexes");
    uint _length = _currentValidatorIndexes.length;
    currentValidatorSet_ = new address[](_length);
    for (uint i = 0; i < _length; i++) {
      console.log("[ ] \t _i, _currentIndexes[i]", i, _currentValidatorIndexes[i]);
      currentValidatorSet_[i] = validatorCandidates[_currentValidatorIndexes[i]].consensusAddr;
    }
    return currentValidatorSet_;
  }

  function getPendingRenouncingValidatorIndexes() public view returns (uint[] memory pendingRenouncingIndexes_) {
    uint _length = _pendingRenouncingValidatorIndexes.length;
    pendingRenouncingIndexes_ = new uint[](_length);
    for (uint i = 0; i < _length; i++) {
      pendingRenouncingIndexes_[i] = _pendingRenouncingValidatorIndexes[i];
    }
  }

  function governanceAdminContract() external view override returns (address) {}

  function setMinValidatorBalance(uint256) external override {}

  function maxValidatorCandidate() external view override returns (uint256) {}

  function setMaxValidatorCandidate(uint256) external override {}

  function getValidatorCandidates() external view override returns (ValidatorCandidate[] memory candidates) {}

  function recordRewardForDelegators(address _consensusAddr, uint256 _reward) external payable override {}

  function settleRewardPoolForDelegators(address _consensusAddr) external override {}

  function sinkPendingReward(address _consensusAddr) external override {}

  function deductStakingAmount(address _consensusAddr, uint256 _amount) external override {}

  function renounce(address consensusAddr) external override {}

  function getRewards(address _user, address[] calldata _poolAddrList)
    external
    view
    override
    returns (uint256[] memory _pendings, uint256[] memory _claimables)
  {}

  function claimRewards(address[] calldata _consensusAddrList) external override returns (uint256 _amount) {}

  function getCandidateWeights()
    external
    view
    override
    returns (address[] memory _candidates, uint256[] memory _weights)
  {}

  function commissionRateOf(address _consensusAddr) external view override returns (uint256 _rate) {}

  function treasuryAddressOf(address _consensusAddr) external view override returns (address) {}
}
