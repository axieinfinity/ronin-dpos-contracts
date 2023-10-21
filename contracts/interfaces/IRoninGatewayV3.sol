// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Transfer.sol";
import "./consumers/MappedTokenConsumer.sol";

interface IRoninGatewayV3 is MappedTokenConsumer {
  /**
   * @dev Error thrown when attempting to withdraw funds that have already been migrated.
   */
  error ErrWithdrawalsMigrated();

  /**
   * @dev Error thrown when an invalid trusted threshold is specified.
   */
  error ErrInvalidTrustedThreshold();

  /**
   * @dev Error thrown when attempting to withdraw funds that have already been withdrawn on the mainchain.
   */
  error ErrWithdrawnOnMainchainAlready();

  /// @dev Emitted when the assets are depositted
  event Deposited(bytes32 receiptHash, Transfer.Receipt receipt);
  /// @dev Emitted when the withdrawal is requested
  event WithdrawalRequested(bytes32 receiptHash, Transfer.Receipt);
  /// @dev Emitted when the assets are withdrawn on mainchain
  event MainchainWithdrew(bytes32 receiptHash, Transfer.Receipt receipt);
  /// @dev Emitted when the withdrawal signatures is requested
  event WithdrawalSignaturesRequested(bytes32 receiptHash, Transfer.Receipt);
  /// @dev Emitted when the tokens are mapped
  event TokenMapped(address[] roninTokens, address[] mainchainTokens, uint256[] chainIds, Token.Standard[] standards);
  /// @dev Emitted when the threshold is updated
  event TrustedThresholdUpdated(
    uint256 indexed nonce,
    uint256 indexed numerator,
    uint256 indexed denominator,
    uint256 previousNumerator,
    uint256 previousDenominator
  );
  /// @dev Emitted when a deposit is voted
  event DepositVoted(address indexed bridgeOperator, uint256 indexed id, uint256 indexed chainId, bytes32 receiptHash);

  /**
   * @dev Returns withdrawal count.
   */
  function withdrawalCount() external view returns (uint256);

  /**
   * @dev Returns withdrawal signatures.
   */
  function getWithdrawalSignatures(
    uint256 _withdrawalId,
    address[] calldata _validators
  ) external view returns (bytes[] memory);

  /**
   * @dev Deposits based on the receipt.
   *
   * Requirements:
   * - The method caller is a validator.
   *
   * Emits the `Deposited` once the assets are released.
   *
   * @notice The assets will be transferred whenever the valid call passes the quorum threshold.
   *
   */
  function depositFor(Transfer.Receipt calldata _receipt) external;

  /**
   * @dev Marks the withdrawals are done on mainchain and returns the boolean array indicating whether the withdrawal
   * vote is already done before.
   *
   * Requirements:
   * - The method caller is a validator.
   *
   * Emits the `MainchainWithdrew` once the valid call passes the quorum threshold.
   *
   * @notice Not reverting to avoid unnecessary failed transactions because the validators can send transactions at the
   * same time.
   *
   */
  function tryBulkAcknowledgeMainchainWithdrew(uint256[] calldata _withdrawalIds) external returns (bool[] memory);

  /**
   * @dev Tries bulk deposits based on the receipts and returns the boolean array indicating whether the deposit vote
   * is already done before. Reverts if the deposit is invalid or is voted by the validator again.
   *
   * Requirements:
   * - The method caller is a validator.
   *
   * Emits the `Deposited` once the assets are released.
   *
   * @notice The assets will be transferred whenever the valid call for the receipt passes the quorum threshold. Not
   * reverting to avoid unnecessary failed transactions because the validators can send transactions at the same time.
   *
   */
  function tryBulkDepositFor(Transfer.Receipt[] calldata _receipts) external returns (bool[] memory);

  /**
   * @dev Locks the assets and request withdrawal.
   *
   * Emits the `WithdrawalRequested` event.
   *
   */
  function requestWithdrawalFor(Transfer.Request calldata _request, uint256 _chainId) external;

  /**
   * @dev Bulk requests withdrawals.
   *
   * Emits the `WithdrawalRequested` events.
   *
   */
  function bulkRequestWithdrawalFor(Transfer.Request[] calldata _requests, uint256 _chainId) external;

  /**
   * @dev Requests withdrawal signatures for a specific withdrawal.
   *
   * Emits the `WithdrawalSignaturesRequested` event.
   *
   */
  function requestWithdrawalSignatures(uint256 _withdrawalId) external;

  /**
   * @dev Submits withdrawal signatures.
   *
   * Requirements:
   * - The method caller is a validator.
   *
   */
  function bulkSubmitWithdrawalSignatures(uint256[] calldata _withdrawals, bytes[] calldata _signatures) external;

  /**
   * @dev Maps Ronin tokens to mainchain networks.
   *
   * Requirement:
   * - The method caller is admin.
   * - The arrays have the same length and its length larger than 0.
   *
   * Emits the `TokenMapped` event.
   *
   */
  function mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata chainIds,
    Token.Standard[] calldata _standards
  ) external;

  /**
   * @dev Returns whether the deposit is casted by the voter.
   */
  function depositVoted(uint256 _chainId, uint256 _depositId, address _voter) external view returns (bool);

  /**
   * @dev Returns whether the mainchain withdrew is casted by the voter.
   */
  function mainchainWithdrewVoted(uint256 _withdrawalId, address _voter) external view returns (bool);

  /**
   * @dev Returns whether the withdrawal is done on mainchain.
   */
  function mainchainWithdrew(uint256 _withdrawalId) external view returns (bool);

  /**
   * @dev Returns mainchain token address.
   * Reverts for unsupported token.
   */
  function getMainchainToken(address _roninToken, uint256 _chainId) external view returns (MappedToken memory _token);
}
