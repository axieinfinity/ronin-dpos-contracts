// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/GatewayV2.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/MinimumWithdrawal.sol";
import "../../interfaces/IERC20Mintable.sol";
import "../../interfaces/IERC721Mintable.sol";
import "../../interfaces/IBridgeTracking.sol";
import "../../interfaces/IRoninGatewayV2.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../libraries/IsolatedGovernance.sol";
import "../../interfaces/IBridgeAdmin.sol";

contract RoninGatewayV2 is
  GatewayV2,
  Initializable,
  MinimumWithdrawal,
  AccessControlEnumerable,
  VoteStatusConsumer,
  IRoninGatewayV2,
  HasContracts
{
  using Token for Token.Info;
  using Transfer for Transfer.Request;
  using Transfer for Transfer.Receipt;
  using IsolatedGovernance for IsolatedGovernance.Vote;
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev Withdrawal unlocker role hash
  bytes32 public constant WITHDRAWAL_MIGRATOR = keccak256("WITHDRAWAL_MIGRATOR");

  /// @dev Flag indicating whether the withdrawal migrate progress is done
  bool public withdrawalMigrated;
  /// @dev Total withdrawal
  uint256 public withdrawalCount;
  /// @dev Mapping from chain id => deposit id => deposit vote
  mapping(uint256 => mapping(uint256 => IsolatedGovernance.Vote)) public depositVote;
  /// @dev Mapping from withdrawal id => mainchain withdrew vote
  mapping(uint256 => IsolatedGovernance.Vote) public mainchainWithdrewVote;
  /// @dev Mapping from withdrawal id => withdrawal receipt
  mapping(uint256 => Transfer.Receipt) public withdrawal;
  /// @dev Mapping from withdrawal id => validator address => signatures
  mapping(uint256 => mapping(address => bytes)) internal _withdrawalSig;
  /// @dev Mapping from token address => chain id => mainchain token address
  mapping(address => mapping(uint256 => MappedToken)) internal _mainchainToken;

  /// @custom:deprecated Previously `_validatorContract` (non-zero value)
  address private ____deprecated0;
  /// @custom:deprecated Previously `_bridgeTrackingContract` (non-zero value)
  address private ____deprecated1;

  /// @dev Mapping from withdrawal id => vote for recording withdrawal stats
  mapping(uint256 => IsolatedGovernance.Vote) public withdrawalStatVote;

  /// @custom:deprecated Previously `_trustedOrgContract` (non-zero value)
  address private ____deprecated2;

  uint256 internal _trustedNum;
  uint256 internal _trustedDenom;

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  modifier onlyBridgeOperator() {
    _requireBridgeOperator();
    _;
  }

  /**
   * @dev Reverts if the method caller is not bridge operator.
   */
  function _requireBridgeOperator() internal view {
    if (!IBridgeAdmin(getContract(ContractType.VALIDATOR)).isBridgeOperator(msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.__DEPRECATED_BRIDGE_OPERATOR);
  }

  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    uint256 _numerator,
    uint256 _denominator,
    uint256 _trustedNumerator,
    uint256 _trustedDenominator,
    address[] calldata _withdrawalMigrators,
    // _packedAddresses[0]: roninTokens
    // _packedAddresses[1]: mainchainTokens
    address[][2] calldata _packedAddresses,
    // _packedNumbers[0]: chainIds
    // _packedNumbers[1]: minimumThresholds
    uint256[][2] calldata _packedNumbers,
    Token.Standard[] calldata _standards
  ) external virtual initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    _setThreshold(_numerator, _denominator);
    _setTrustedThreshold(_trustedNumerator, _trustedDenominator);
    if (_packedAddresses[0].length > 0) {
      _mapTokens(_packedAddresses[0], _packedAddresses[1], _packedNumbers[0], _standards);
      _setMinimumThresholds(_packedAddresses[0], _packedNumbers[1]);
    }

    for (uint256 _i; _i < _withdrawalMigrators.length; ) {
      _grantRole(WITHDRAWAL_MIGRATOR, _withdrawalMigrators[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  function initializeV2(address bridgeAdmin) external reinitializer(2) {
    _setContract(ContractType.BRIDGE_ADMIN, bridgeAdmin);
  }

  /**
   * @dev Migrates withdrawals.
   *
   * Requirements:
   * - The method caller is the migrator.
   * - The arrays have the same length and its length larger than 0.
   *
   */
  function migrateWithdrawals(
    Transfer.Request[] calldata _requests,
    address[] calldata _requesters
  ) external onlyRole(WITHDRAWAL_MIGRATOR) {
    if (withdrawalMigrated) revert ErrWithdrawalsMigrated();
    if (!(_requesters.length == _requests.length && _requests.length > 0)) revert ErrLengthMismatch(msg.sig);

    for (uint256 _i; _i < _requests.length; ) {
      MappedToken memory _token = getMainchainToken(_requests[_i].tokenAddr, 1);
      if (_requests[_i].info.erc != _token.erc) revert ErrInvalidTokenStandard();

      _storeAsReceipt(_requests[_i], 1, _requesters[_i], _token.tokenAddr);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Mark the migration as done.
   */
  function markWithdrawalMigrated() external {
    if (!(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(WITHDRAWAL_MIGRATOR, msg.sender))) {
      revert ErrUnauthorized(msg.sig, RoleAccess.WITHDRAWAL_MIGRATOR);
    }
    if (withdrawalMigrated) revert ErrWithdrawalsMigrated();

    withdrawalMigrated = true;
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function getWithdrawalSignatures(
    uint256 _withdrawalId,
    address[] calldata _validators
  ) external view returns (bytes[] memory _signatures) {
    _signatures = new bytes[](_validators.length);
    for (uint256 _i = 0; _i < _validators.length; ) {
      _signatures[_i] = _withdrawalSig[_withdrawalId][_validators[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function depositFor(Transfer.Receipt calldata _receipt) external whenNotPaused onlyBridgeOperator {
    address _sender = msg.sender;
    _depositFor(_receipt, _sender, minimumVoteWeight(), minimumTrustedVoteWeight());
    IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING)).recordVote(
      IBridgeTracking.VoteKind.Deposit,
      _receipt.id,
      _sender
    );
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function tryBulkAcknowledgeMainchainWithdrew(
    uint256[] calldata _withdrawalIds
  ) external onlyBridgeOperator returns (bool[] memory _executedReceipts) {
    address _governor = msg.sender;
    uint256 _minVoteWeight = minimumVoteWeight();
    uint256 _minTrustedVoteWeight = minimumTrustedVoteWeight();

    uint256 _withdrawalId;
    _executedReceipts = new bool[](_withdrawalIds.length);
    IBridgeTracking _bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint256 _i; _i < _withdrawalIds.length; ) {
      _withdrawalId = _withdrawalIds[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.MainchainWithdrawal, _withdrawalId, _governor);
      if (mainchainWithdrew(_withdrawalId)) {
        _executedReceipts[_i] = true;
      } else {
        IsolatedGovernance.Vote storage _vote = mainchainWithdrewVote[_withdrawalId];
        Transfer.Receipt memory _withdrawal = withdrawal[_withdrawalId];
        bytes32 _hash = _withdrawal.hash();
        VoteStatus _status = _castIsolatedVote(_vote, _governor, _minVoteWeight, _minTrustedVoteWeight, _hash);
        if (_status == VoteStatus.Approved) {
          _vote.status = VoteStatus.Executed;
          _bridgeTrackingContract.handleVoteApproved(IBridgeTracking.VoteKind.MainchainWithdrawal, _withdrawalId);
          emit MainchainWithdrew(_hash, _withdrawal);
        }
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function tryBulkDepositFor(
    Transfer.Receipt[] calldata _receipts
  ) external whenNotPaused onlyBridgeOperator returns (bool[] memory _executedReceipts) {
    address _sender = msg.sender;

    Transfer.Receipt memory _receipt;
    _executedReceipts = new bool[](_receipts.length);
    uint256 _minVoteWeight = minimumVoteWeight();
    uint256 _minTrustedVoteWeight = minimumTrustedVoteWeight();
    IBridgeTracking _bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint256 _i; _i < _receipts.length; ) {
      _receipt = _receipts[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Deposit, _receipt.id, _sender);
      if (depositVote[_receipt.mainchain.chainId][_receipt.id].status == VoteStatus.Executed) {
        _executedReceipts[_i] = true;
      } else {
        _depositFor(_receipt, _sender, _minVoteWeight, _minTrustedVoteWeight);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function requestWithdrawalFor(Transfer.Request calldata _request, uint256 _chainId) external whenNotPaused {
    _requestWithdrawalFor(_request, msg.sender, _chainId);
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function bulkRequestWithdrawalFor(Transfer.Request[] calldata _requests, uint256 _chainId) external whenNotPaused {
    if (_requests.length == 0) revert ErrEmptyArray();

    for (uint256 _i; _i < _requests.length; ) {
      _requestWithdrawalFor(_requests[_i], msg.sender, _chainId);
      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function requestWithdrawalSignatures(uint256 _withdrawalId) external whenNotPaused {
    if (mainchainWithdrew(_withdrawalId)) revert ErrWithdrawnOnMainchainAlready();

    Transfer.Receipt memory _receipt = withdrawal[_withdrawalId];
    if (_receipt.ronin.chainId != block.chainid) {
      revert ErrInvalidChainId(msg.sig, _receipt.ronin.chainId, block.chainid);
    }

    emit WithdrawalSignaturesRequested(_receipt.hash(), _receipt);
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function bulkSubmitWithdrawalSignatures(
    uint256[] calldata _withdrawals,
    bytes[] calldata _signatures
  ) external whenNotPaused onlyBridgeOperator {
    address _validator = msg.sender;

    if (!(_withdrawals.length > 0 && _withdrawals.length == _signatures.length)) {
      revert ErrLengthMismatch(msg.sig);
    }

    uint256 _minVoteWeight = minimumVoteWeight();
    uint256 _minTrustedVoteWeight = minimumTrustedVoteWeight();

    uint256 _id;
    IBridgeTracking _bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint256 _i; _i < _withdrawals.length; ) {
      _id = _withdrawals[_i];
      _withdrawalSig[_id][_validator] = _signatures[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Withdrawal, _id, _validator);

      IsolatedGovernance.Vote storage _proposal = withdrawalStatVote[_id];
      VoteStatus _status = _castIsolatedVote(
        _proposal,
        _validator,
        _minVoteWeight,
        _minTrustedVoteWeight,
        bytes32(_id)
      );
      if (_status == VoteStatus.Approved) {
        _proposal.status = VoteStatus.Executed;
        _bridgeTrackingContract.handleVoteApproved(IBridgeTracking.VoteKind.Withdrawal, _id);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata _chainIds,
    Token.Standard[] calldata _standards
  ) external onlyAdmin {
    if (_roninTokens.length == 0) revert ErrLengthMismatch(msg.sig);
    _mapTokens(_roninTokens, _mainchainTokens, _chainIds, _standards);
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function depositVoted(uint256 _chainId, uint256 _depositId, address _voter) external view returns (bool) {
    return depositVote[_chainId][_depositId].voted(_voter);
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function mainchainWithdrewVoted(uint256 _withdrawalId, address _voter) external view returns (bool) {
    return mainchainWithdrewVote[_withdrawalId].voted(_voter);
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function mainchainWithdrew(uint256 _withdrawalId) public view returns (bool) {
    return mainchainWithdrewVote[_withdrawalId].status == VoteStatus.Executed;
  }

  /**
   * @inheritdoc IRoninGatewayV2
   */
  function getMainchainToken(address _roninToken, uint256 _chainId) public view returns (MappedToken memory _token) {
    _token = _mainchainToken[_roninToken][_chainId];
    if (_token.tokenAddr == address(0)) revert ErrUnsupportedToken();
  }

  /**
   * @dev Maps Ronin tokens to mainchain networks.
   *
   * Requirement:
   * - The arrays have the same length.
   *
   * Emits the `TokenMapped` event.
   *
   */
  function _mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata _chainIds,
    Token.Standard[] calldata _standards
  ) internal {
    if (!(_roninTokens.length == _mainchainTokens.length && _roninTokens.length == _chainIds.length))
      revert ErrLengthMismatch(msg.sig);

    for (uint256 _i; _i < _roninTokens.length; ) {
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].tokenAddr = _mainchainTokens[_i];
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].erc = _standards[_i];

      unchecked {
        ++_i;
      }
    }

    emit TokenMapped(_roninTokens, _mainchainTokens, _chainIds, _standards);
  }

  /**
   * @dev Deposits based on the receipt.
   *
   * Emits the `Deposited` once the assets are released.
   *
   */
  function _depositFor(
    Transfer.Receipt memory _receipt,
    address _validator,
    uint256 _minVoteWeight,
    uint256 _minTrustedVoteWeight
  ) internal {
    uint256 _id = _receipt.id;
    _receipt.info.validate();
    if (_receipt.kind != Transfer.Kind.Deposit) revert ErrInvalidReceiptKind();

    if (_receipt.ronin.chainId != block.chainid)
      revert ErrInvalidChainId(msg.sig, _receipt.ronin.chainId, block.chainid);

    MappedToken memory _token = getMainchainToken(_receipt.ronin.tokenAddr, _receipt.mainchain.chainId);

    if (!(_token.erc == _receipt.info.erc && _token.tokenAddr == _receipt.mainchain.tokenAddr))
      revert ErrInvalidReceipt();

    IsolatedGovernance.Vote storage _proposal = depositVote[_receipt.mainchain.chainId][_id];
    bytes32 _receiptHash = _receipt.hash();
    VoteStatus _status = _castIsolatedVote(_proposal, _validator, _minVoteWeight, _minTrustedVoteWeight, _receiptHash);
    emit DepositVoted(_validator, _id, _receipt.mainchain.chainId, _receiptHash);
    if (_status == VoteStatus.Approved) {
      _proposal.status = VoteStatus.Executed;
      _receipt.info.handleAssetTransfer(payable(_receipt.ronin.addr), _receipt.ronin.tokenAddr, IWETH(address(0)));
      IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING)).handleVoteApproved(
        IBridgeTracking.VoteKind.Deposit,
        _receipt.id
      );
      emit Deposited(_receiptHash, _receipt);
    }
  }

  /**
   * @dev Locks the assets and request withdrawal.
   *
   * Requirements:
   * - The token info is valid.
   *
   * Emits the `WithdrawalRequested` event.
   *
   */
  function _requestWithdrawalFor(Transfer.Request calldata _request, address _requester, uint256 _chainId) internal {
    _request.info.validate();
    _checkWithdrawal(_request);
    MappedToken memory _token = getMainchainToken(_request.tokenAddr, _chainId);
    if (_request.info.erc != _token.erc) revert ErrInvalidTokenStandard();

    _request.info.transferFrom(_requester, address(this), _request.tokenAddr);
    _storeAsReceipt(_request, _chainId, _requester, _token.tokenAddr);
  }

  /**
   * @dev Stores the withdrawal request as a receipt.
   *
   * Emits the `WithdrawalRequested` event.
   *
   */
  function _storeAsReceipt(
    Transfer.Request calldata _request,
    uint256 _chainId,
    address _requester,
    address _mainchainTokenAddr
  ) internal returns (uint256 _withdrawalId) {
    _withdrawalId = withdrawalCount++;
    Transfer.Receipt memory _receipt = _request.into_withdrawal_receipt(
      _requester,
      _withdrawalId,
      _mainchainTokenAddr,
      _chainId
    );
    withdrawal[_withdrawalId] = _receipt;
    emit WithdrawalRequested(_receipt.hash(), _receipt);
  }

  /**
   * @dev Don't send me RON.
   */
  function _fallback() internal virtual {
    revert ErrInvalidRequest();
  }

  /**
   * @inheritdoc GatewayV2
   */
  function _getTotalWeight() internal view virtual override returns (uint256) {
    // return IRoninValidatorSet(getContract(ContractType.VALIDATOR)).totalBridgeOperators();
  }

  /**
   * @dev Returns the total trusted weight.
   */
  function _getTotalTrustedWeight() internal view virtual returns (uint256) {
    return IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).countTrustedOrganizations();
  }

  /**
   * @dev Casts and updates the vote result.
   *
   * Requirements:
   * - The vote is not finalized.
   * - The voter has not voted for the round.
   *
   */
  function _castIsolatedVote(
    IsolatedGovernance.Vote storage _v,
    address _voter,
    uint256 _minVoteWeight,
    uint256 _minTrustedVoteWeight,
    bytes32 _hash
  ) internal virtual returns (VoteStatus _status) {
    _v.castVote(_voter, _hash);
    (uint256 _totalWeight, uint256 _trustedWeight) = _getVoteWeight(_v, _hash);
    return _v.syncVoteStatus(_minVoteWeight, _totalWeight, _minTrustedVoteWeight, _trustedWeight, _hash);
  }

  /**
   * @dev Returns the vote weight for a specified hash.
   */
  function _getVoteWeight(
    IsolatedGovernance.Vote storage _v,
    bytes32 _hash
  ) internal view returns (uint256 _totalWeight, uint256 _trustedWeight) {
    address[] memory _bridgeOperators = IBridgeAdmin(getContract(ContractType.BRIDGE_ADMIN)).getBridgeOperators();
    address[] memory _consensusList = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidators();
    uint256[] memory _trustedWeights = IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION))
      .getConsensusWeights(_consensusList);

    unchecked {
      for (uint _i; _i < _bridgeOperators.length; ++_i) {
        if (_v.voteHashOf[_bridgeOperators[_i]] == _hash) {
          _totalWeight++;
          if (_trustedWeights[_i] > 0) {
            _trustedWeight++;
          }
        }
      }
    }
  }

  function setTrustedThreshold(
    uint256 _trustedNumerator,
    uint256 _trustedDenominator
  ) external virtual onlyAdmin returns (uint256, uint256) {
    return _setTrustedThreshold(_trustedNumerator, _trustedDenominator);
  }

  /**
   * @dev Returns the minimum trusted vote weight to pass the threshold.
   */
  function minimumTrustedVoteWeight() public view virtual returns (uint256) {
    return _minimumTrustedVoteWeight(_getTotalTrustedWeight());
  }

  /**
   * @dev Returns the threshold about trusted org.
   */
  function getTrustedThreshold() external view virtual returns (uint256 trustedNum_, uint256 trustedDenom_) {
    return (_trustedNum, _trustedDenom);
  }

  /**
   * @dev Sets trusted threshold and returns the old one.
   *
   * Emits the `TrustedThresholdUpdated` event.
   *
   */
  function _setTrustedThreshold(
    uint256 _trustedNumerator,
    uint256 _trustedDenominator
  ) internal virtual returns (uint256 _previousTrustedNum, uint256 _previousTrustedDenom) {
    if (_trustedNumerator > _trustedDenominator) revert ErrInvalidTrustedThreshold();

    _previousTrustedNum = _num;
    _previousTrustedDenom = _denom;
    _trustedNum = _trustedNumerator;
    _trustedDenom = _trustedDenominator;
    unchecked {
      emit TrustedThresholdUpdated(
        nonce++,
        _trustedNumerator,
        _trustedDenominator,
        _previousTrustedNum,
        _previousTrustedDenom
      );
    }
  }

  /**
   * @dev Returns minimum trusted vote weight.
   */
  function _minimumTrustedVoteWeight(uint256 _totalTrustedWeight) internal view virtual returns (uint256) {
    return (_trustedNum * _totalTrustedWeight + _trustedDenom - 1) / _trustedDenom;
  }
}
