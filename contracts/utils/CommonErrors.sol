// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType } from "./ContractType.sol";
import { RoleAccess } from "./RoleAccess.sol";

/**
 * @dev Error indicating that given address is null when it should not.
 */
error ErrZeroAddress(bytes4 msgSig);
/**
 * @dev Error indicating that the provided threshold is invalid for a specific function signature.
 * @param msgSig The function signature (bytes4) that the invalid threshold applies to.
 */
error ErrInvalidThreshold(bytes4 msgSig);

/**
 * @dev Error indicating that a function can only be called by the contract itself.
 * @param msgSig The function signature (bytes4) that can only be called by the contract itself.
 */
error ErrOnlySelfCall(bytes4 msgSig);

/**
 * @dev Error indicating that the caller is unauthorized to perform a specific function.
 * @param msgSig The function signature (bytes4) that the caller is unauthorized to perform.
 * @param expectedRole The role required to perform the function.
 */
error ErrUnauthorized(bytes4 msgSig, RoleAccess expectedRole);

/**
 * @dev Error indicating that the caller is unauthorized to perform a specific function.
 * @param msgSig The function signature (bytes4).
 * @param expectedContractType The contract type required to perform the function.
 * @param actual The actual address that called to the function.
 */
error ErrUnexpectedInternalCall(bytes4 msgSig, ContractType expectedContractType, address actual);

/**
 * @dev Error indicating that an array is empty when it should contain elements.
 */
error ErrEmptyArray();

/**
 * @dev Error indicating a mismatch in the length of input parameters or arrays for a specific function.
 * @param msgSig The function signature (bytes4) that has a length mismatch.
 */
error ErrLengthMismatch(bytes4 msgSig);

/**
 * @dev Error indicating that a proxy call to an external contract has failed.
 * @param msgSig The function signature (bytes4) of the proxy call that failed.
 * @param extCallSig The function signature (bytes4) of the external contract call that failed.
 */
error ErrProxyCallFailed(bytes4 msgSig, bytes4 extCallSig);

/**
 * @dev Error indicating that a function tried to call a precompiled contract that is not allowed.
 * @param msgSig The function signature (bytes4) that attempted to call a precompiled contract.
 */
error ErrCallPrecompiled(bytes4 msgSig);

/**
 * @dev Error indicating that a native token transfer has failed.
 * @param msgSig The function signature (bytes4) of the token transfer that failed.
 */
error ErrNativeTransferFailed(bytes4 msgSig);

/**
 * @dev Error indicating that an order is invalid.
 * @param msgSig The function signature (bytes4) of the operation that encountered an invalid order.
 */
error ErrInvalidOrder(bytes4 msgSig);

/**
 * @dev Error indicating that the chain ID is invalid.
 * @param msgSig The function signature (bytes4) of the operation that encountered an invalid chain ID.
 * @param actual Current chain ID that executing function.
 * @param expected Expected chain ID required for the tx to success.
 */
error ErrInvalidChainId(bytes4 msgSig, uint256 actual, uint256 expected);

/**
 * @dev Error indicating that a vote type is not supported.
 * @param msgSig The function signature (bytes4) of the operation that encountered an unsupported vote type.
 */
error ErrUnsupportedVoteType(bytes4 msgSig);

/**
 * @dev Error indicating that the proposal nonce is invalid.
 * @param msgSig The function signature (bytes4) of the operation that encountered an invalid proposal nonce.
 */
error ErrInvalidProposalNonce(bytes4 msgSig);

/**
 * @dev Error indicating that a voter has already voted.
 * @param voter The address of the voter who has already voted.
 */
error ErrAlreadyVoted(address voter);

/**
 * @dev Error indicating that a signature is invalid for a specific function signature.
 * @param msgSig The function signature (bytes4) that encountered an invalid signature.
 */
error ErrInvalidSignatures(bytes4 msgSig);

/**
 * @dev Error indicating that a relay call has failed.
 * @param msgSig The function signature (bytes4) of the relay call that failed.
 */
error ErrRelayFailed(bytes4 msgSig);
/**
 * @dev Error indicating that a vote weight is invalid for a specific function signature.
 * @param msgSig The function signature (bytes4) that encountered an invalid vote weight.
 */
error ErrInvalidVoteWeight(bytes4 msgSig);

/**
 * @dev Error indicating that a query was made for an outdated bridge operator set.
 */
error ErrQueryForOutdatedBridgeOperatorSet();

/**
 * @dev Error indicating that a request is invalid.
 */
error ErrInvalidRequest();

/**
 * @dev Error indicating that a token standard is invalid.
 */
error ErrInvalidTokenStandard();

/**
 * @dev Error indicating that a token is not supported.
 */
error ErrUnsupportedToken();

/**
 * @dev Error indicating that a receipt kind is invalid.
 */
error ErrInvalidReceiptKind();

/**
 * @dev Error indicating that a receipt is invalid.
 */
error ErrInvalidReceipt();
