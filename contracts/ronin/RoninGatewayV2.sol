// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/GatewayV2.sol";
import "../extensions/isolated-governance/IsolatedGovernance.sol";
import "../extensions/MinimumWithdrawal.sol";
import "../interfaces/IERC20Mintable.sol";
import "../interfaces/IERC721Mintable.sol";
import "../interfaces/IRoninGatewayV2.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../interfaces/IBridgeTracking.sol";
import "../interfaces/collections/IHasValidatorContract.sol";
import "../interfaces/collections/IHasBridgeTrackingContract.sol";

contract RoninGatewayV2 is
  GatewayV2,
  IsolatedGovernance,
  Initializable,
  MinimumWithdrawal,
  AccessControlEnumerable,
  IRoninGatewayV2,
  IHasValidatorContract,
  IHasBridgeTrackingContract
{
  using Token for Token.Info;
  using Transfer for Transfer.Request;
  using Transfer for Transfer.Receipt;

  /// @dev Withdrawal unlocker role hash
  bytes32 public constant WITHDRAWAL_MIGRATOR = keccak256("WITHDRAWAL_MIGRATOR");

  /// @dev Flag indicating whether the withdrawal migrate progress is done
  bool public withdrawalMigrated;
  /// @dev Total withdrawal
  uint256 public withdrawalCount;
  /// @dev Mapping from chain id => deposit id => deposit vote
  mapping(uint256 => mapping(uint256 => IsolatedVote)) public depositVote;
  /// @dev Mapping from withdrawal id => mainchain withdrew vote
  mapping(uint256 => IsolatedVote) public mainchainWithdrewVote;
  /// @dev Mapping from withdrawal id => withdrawal receipt
  mapping(uint256 => Transfer.Receipt) public withdrawal;
  /// @dev Mapping from withdrawal id => validator address => signatures
  mapping(uint256 => mapping(address => bytes)) internal _withdrawalSig;
  /// @dev Mapping from token address => chain id => mainchain token address
  mapping(address => mapping(uint256 => MappedToken)) internal _mainchainToken;

  /// @dev The ronin validator contract
  IRoninValidatorSet internal _validatorContract;
  /// @dev The bridge tracking contract
  IBridgeTracking internal _bridgeTrackingContract;

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    uint256 _numerator,
    uint256 _denominator,
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
    if (_packedAddresses[0].length > 0) {
      _mapTokens(_packedAddresses[0], _packedAddresses[1], _packedNumbers[0], _standards);
      _setMinimumThresholds(_packedAddresses[0], _packedNumbers[1]);
    }

    for (uint256 _i; _i < _withdrawalMigrators.length; _i++) {
      _grantRole(WITHDRAWAL_MIGRATOR, _withdrawalMigrators[_i]);
    }
  }

  /**
   * @inheritdoc IHasValidatorContract
   */
  function validatorContract() external view returns (address) {
    return address(_validatorContract);
  }

  /**
   * @inheritdoc IHasValidatorContract
   */
  function setValidatorContract(address _addr) external override onlyAdmin {
    _setValidatorContract(_addr);
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function bridgeTrackingContract() external view override returns (address) {
    return address(_bridgeTrackingContract);
  }

  /**
   * @inheritdoc IHasBridgeTrackingContract
   */
  function setBridgeTrackingContract(address _addr) external override onlyAdmin {
    _setBridgeTrackingContract(_addr);
  }

  /**
   * @dev Migrates withdrawals.
   *
   * Requirements:
   * - The method caller is the migrator.
   * - The arrays have the same length and its length larger than 0.
   *
   */
  function migrateWithdrawals(Transfer.Request[] calldata _requests, address[] calldata _requesters)
    external
    onlyRole(WITHDRAWAL_MIGRATOR)
  {
    require(!withdrawalMigrated, "RoninGatewayV2: withdrawals migrated");
    require(_requesters.length == _requests.length && _requests.length > 0, "RoninGatewayV2: invalid array lengths");
    for (uint256 _i; _i < _requests.length; _i++) {
      MappedToken memory _token = getMainchainToken(_requests[_i].tokenAddr, 1);
      require(_requests[_i].info.erc == _token.erc, "RoninGatewayV2: invalid token standard");
      _storeAsReceipt(_requests[_i], 1, _requesters[_i], _token.tokenAddr);
    }
  }

  /**
   * @dev Mark the migration as done.
   */
  function markWithdrawalMigrated() external {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(WITHDRAWAL_MIGRATOR, msg.sender),
      "RoninGatewayV2: unauthorized sender"
    );
    require(!withdrawalMigrated, "RoninGatewayV2: withdrawals migrated");
    withdrawalMigrated = true;
  }

  /**
   * @dev {IRoninGatewayV2-getWithdrawalSignatures}.
   */
  function getWithdrawalSignatures(uint256 _withdrawalId, address[] calldata _validators)
    external
    view
    returns (bytes[] memory _signatures)
  {
    _signatures = new bytes[](_validators.length);
    for (uint256 _i = 0; _i < _validators.length; _i++) {
      _signatures[_i] = _withdrawalSig[_withdrawalId][_validators[_i]];
    }
  }

  /**
   * @dev {IRoninGatewayV2-depositFor}.
   */
  function depositFor(Transfer.Receipt calldata _receipt) external {
    address _sender = msg.sender;
    uint256 _weight = _getValidatorWeight(_sender);
    _depositFor(_receipt, _sender, _weight, minimumVoteWeight());
    _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Deposit, _receipt.id, _sender);
  }

  /**
   * @dev {IRoninGatewayV2-tryBulkAcknowledgeMainchainWithdrew}.
   */
  function tryBulkAcknowledgeMainchainWithdrew(uint256[] calldata _withdrawalIds)
    external
    returns (bool[] memory _executedReceipts)
  {
    address _governor = msg.sender;
    uint256 _weight = _getValidatorWeight(_governor);
    uint256 _minVoteWeight = minimumVoteWeight();

    uint256 _withdrawalId;
    _executedReceipts = new bool[](_withdrawalIds.length);
    for (uint256 _i; _i < _withdrawalIds.length; _i++) {
      _withdrawalId = _withdrawalIds[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.MainchainWithdrawal, _withdrawalId, _governor);
      if (mainchainWithdrew(_withdrawalId)) {
        _executedReceipts[_i] = true;
      } else {
        IsolatedVote storage _proposal = mainchainWithdrewVote[_withdrawalId];
        Transfer.Receipt memory _withdrawal = withdrawal[_withdrawalId];
        bytes32 _hash = _withdrawal.hash();
        VoteStatus _status = _castVote(_proposal, _governor, _weight, _minVoteWeight, _hash);
        if (_status == VoteStatus.Approved) {
          _proposal.status = VoteStatus.Executed;
          emit MainchainWithdrew(_hash, _withdrawal);
        }
      }
    }
  }

  /**
   * @dev {IRoninGatewayV2-tryBulkDepositFor}.
   */
  function tryBulkDepositFor(Transfer.Receipt[] calldata _receipts) external returns (bool[] memory _executedReceipts) {
    address _sender = msg.sender;
    uint256 _weight = _getValidatorWeight(_sender);

    Transfer.Receipt memory _receipt;
    _executedReceipts = new bool[](_receipts.length);
    uint256 _minVoteWeight = minimumVoteWeight();
    for (uint256 _i; _i < _receipts.length; _i++) {
      _receipt = _receipts[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Deposit, _receipt.id, _sender);
      if (depositVote[_receipt.mainchain.chainId][_receipt.id].status == VoteStatus.Executed) {
        _executedReceipts[_i] = true;
      } else {
        _depositFor(_receipt, _sender, _weight, _minVoteWeight);
      }
    }
  }

  /**
   * @dev {IRoninGatewayV2-requestWithdrawalFor}.
   */
  function requestWithdrawalFor(Transfer.Request calldata _request, uint256 _chainId) external whenNotPaused {
    _requestWithdrawalFor(_request, msg.sender, _chainId);
  }

  /**
   * @dev {IRoninGatewayV2-bulkRequestWithdrawalFor}.
   */
  function bulkRequestWithdrawalFor(Transfer.Request[] calldata _requests, uint256 _chainId) external whenNotPaused {
    require(_requests.length > 0, "RoninGatewayV2: empty array");
    for (uint256 _i; _i < _requests.length; _i++) {
      _requestWithdrawalFor(_requests[_i], msg.sender, _chainId);
    }
  }

  /**
   * @dev {IRoninGatewayV2-requestWithdrawalSignatures}.
   */
  function requestWithdrawalSignatures(uint256 _withdrawalId) external whenNotPaused {
    require(!mainchainWithdrew(_withdrawalId), "RoninGatewayV2: withdrew on mainchain already");
    Transfer.Receipt memory _receipt = withdrawal[_withdrawalId];
    require(_receipt.ronin.chainId == block.chainid, "RoninGatewayV2: query for invalid withdrawal");
    emit WithdrawalSignaturesRequested(_receipt.hash(), _receipt);
  }

  /**
   * @dev {IRoninGatewayV2-bulkSubmitWithdrawalSignatures}.
   */
  function bulkSubmitWithdrawalSignatures(uint256[] calldata _withdrawals, bytes[] calldata _signatures) external {
    address _validator = msg.sender;
    // This checks method caller already
    _getValidatorWeight(_validator);

    require(
      _withdrawals.length > 0 && _withdrawals.length == _signatures.length,
      "RoninGatewayV2: invalid array length"
    );

    uint256 _id;
    for (uint256 _i; _i < _withdrawals.length; _i++) {
      _id = _withdrawals[_i];
      _withdrawalSig[_id][_validator] = _signatures[_i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Withdrawal, _id, _validator);
    }
  }

  /**
   * @dev {IRoninGatewayV2-mapTokens}.
   */
  function mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata _chainIds,
    Token.Standard[] calldata _standards
  ) external onlyAdmin {
    require(_roninTokens.length > 0, "RoninGatewayV2: invalid array length");
    _mapTokens(_roninTokens, _mainchainTokens, _chainIds, _standards);
  }

  /**
   * @dev {IRoninGatewayV2-depositVoted}.
   */
  function depositVoted(
    uint256 _chainId,
    uint256 _depositId,
    address _voter
  ) external view returns (bool) {
    return _voted(depositVote[_chainId][_depositId], _voter);
  }

  /**
   * @dev {IRoninGatewayV2-mainchainWithdrewVoted}.
   */
  function mainchainWithdrewVoted(uint256 _withdrawalId, address _voter) external view returns (bool) {
    return _voted(mainchainWithdrewVote[_withdrawalId], _voter);
  }

  /**
   * @dev {IRoninGatewayV2-mainchainWithdrew}.
   */
  function mainchainWithdrew(uint256 _withdrawalId) public view returns (bool) {
    return mainchainWithdrewVote[_withdrawalId].status == VoteStatus.Executed;
  }

  /**
   * @dev {IRoninGatewayV2-getMainchainToken}.
   */
  function getMainchainToken(address _roninToken, uint256 _chainId) public view returns (MappedToken memory _token) {
    _token = _mainchainToken[_roninToken][_chainId];
    require(_token.tokenAddr != address(0), "RoninGatewayV2: unsupported token");
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
    require(
      _roninTokens.length == _mainchainTokens.length && _roninTokens.length == _chainIds.length,
      "RoninGatewayV2: invalid array length"
    );

    for (uint256 _i; _i < _roninTokens.length; _i++) {
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].tokenAddr = _mainchainTokens[_i];
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].erc = _standards[_i];
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
    uint256 _weight,
    uint256 _minVoteWeight
  ) internal {
    uint256 _id = _receipt.id;
    _receipt.info.validate();
    require(_receipt.kind == Transfer.Kind.Deposit, "RoninGatewayV2: invalid receipt kind");
    require(_receipt.ronin.chainId == block.chainid, "RoninGatewayV2: invalid chain id");
    MappedToken memory _token = getMainchainToken(_receipt.ronin.tokenAddr, _receipt.mainchain.chainId);
    require(
      _token.erc == _receipt.info.erc && _token.tokenAddr == _receipt.mainchain.tokenAddr,
      "RoninGatewayV2: invalid receipt"
    );

    IsolatedVote storage _proposal = depositVote[_receipt.mainchain.chainId][_id];
    bytes32 _receiptHash = _receipt.hash();
    VoteStatus _status = _castVote(_proposal, _validator, _weight, _minVoteWeight, _receiptHash);
    if (_status == VoteStatus.Approved) {
      _proposal.status = VoteStatus.Executed;
      _receipt.info.handleAssetTransfer(payable(_receipt.ronin.addr), _receipt.ronin.tokenAddr, IWETH(address(0)));
      emit Deposited(_receiptHash, _receipt);
    }
  }

  /**
   * @dev Returns the validator weight.
   *
   * Requirements:
   * - The `_addr` weight is larger than 0.
   *
   */
  function _getValidatorWeight(address _addr) internal view returns (uint256 _weight) {
    _weight = _validatorContract.isBridgeOperator(_addr) ? 1 : 0;
    require(_weight > 0, "RoninGatewayV2: unauthorized sender");
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
  function _requestWithdrawalFor(
    Transfer.Request calldata _request,
    address _requester,
    uint256 _chainId
  ) internal {
    _request.info.validate();
    _checkWithdrawal(_request);
    MappedToken memory _token = getMainchainToken(_request.tokenAddr, _chainId);
    require(_request.info.erc == _token.erc, "RoninGatewayV2: invalid token standard");
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
  ) internal {
    uint256 _withdrawalId = withdrawalCount++;
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
    revert("RoninGatewayV2: invalid request");
  }

  /**
   * @inheritdoc GatewayV2
   */
  function _getTotalWeight() internal view virtual override returns (uint256) {
    return _validatorContract.totalBridgeOperators();
  }

  /**
   * @dev Sets the validator contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `ValidatorContractUpdated`.
   *
   */
  function _setValidatorContract(address _addr) internal {
    _validatorContract = IRoninValidatorSet(_addr);
    emit ValidatorContractUpdated(_addr);
  }

  /**
   * @dev Sets the bridge tracking contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `BridgeTrackingContractUpdated`.
   *
   */
  function _setBridgeTrackingContract(address _addr) internal {
    _bridgeTrackingContract = IBridgeTracking(_addr);
    emit BridgeTrackingContractUpdated(_addr);
  }
}
