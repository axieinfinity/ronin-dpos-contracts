// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error ErrInvalidThreshold(bytes4 msgSig);
error ErrOnlySelfCall(bytes4 msgSig);
error ErrUnauthorized(bytes4 msgSig);
error ErrEmptyArrayLength();
error ErrLengthMismatch(bytes4 msgSig);
error ErrProxyCallFailed(bytes4 msgSig, bytes4 extCallSig);

error ErrCallPrecompiled(bytes4 msgSig);

error ErrNativeTransferFailed(bytes4 msgSig);
/// @dev Error of number of prioritized greater than number of max validators.
error ErrInvalidMaxPrioritizedValidatorNumber(bytes4 msgSig);
error ErrInvalidOrder(bytes4 msgSig);
error ErrInvalidChainId(bytes4 msgSig);
error ErrUnsupportedVoteType(bytes4 msgSig);
error ErrInvalidProposalNonce(bytes4 msgSig);

error ErrInvalidSignature(bytes4 msgSig);
error ErrRelayFailed(bytes4 msgSig);
error ErrInvalidVoteWeight(bytes4 msgSig);
error ErrQueryForOutdatedBridgeOperatorSet();
error ErrInvalidRequest();
error ErrInvalidTokenStandard();
error ErrUnsupportedToken();
error ErrInvalidReceiptKind();
error ErrInvalidReceipt();
