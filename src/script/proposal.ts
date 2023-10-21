import { BigNumberish } from 'ethers';
import { AbiCoder, keccak256, solidityKeccak256 } from 'ethers/lib/utils';
import { Address } from 'hardhat-deploy/dist/types';

import { GlobalProposalDetailStruct, ProposalDetailStruct } from '../types/GovernanceAdmin';

// keccak256("ProposalDetail(uint256 nonce,uint256 chainId,uint256 expiryTimestamp,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)")
const proposalTypeHash = '0xd051578048e6ff0bbc9fca3b65a42088dbde10f36ca841de566711087ad9b08a';
// keccak256("GlobalProposalDetail(uint256 nonce,uint256 expiryTimestamp,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)")
const globalProposalTypeHash = '0x1463f426c05aff2c1a7a0957a71c9898bc8b47142540538e79ee25ee91141350';
// keccak256("Ballot(bytes32 proposalHash,uint8 support)")
const ballotTypeHash = '0xd900570327c4c0df8dd6bdd522b7da7e39145dd049d2fd4602276adcd511e3c2';
// keccak256("BridgeOperatorsBallot(uint256 period,uint256 epoch,address[] operators)");
const bridgeOperatorsBallotTypeHash = '0xd679a49e9e099fa9ed83a5446aaec83e746b03ec6723d6f5efb29d37d7f0b78a';
// keccak256("EmergencyExitBallot(address consensusAddress,address recipientAfterUnlockedFund,uint256 requestedAt,uint256 expiredAt)");
const emergencyExitBallotTypehash = '0x697acba4deaf1a718d8c2d93e42860488cb7812696f28ca10eed17bac41e7027';

export enum VoteType {
  For = 0,
  Against = 1,
}

export enum VoteStatus {
  Pending = 0,
  Approved = 1,
  Executed = 2,
  Rejected = 3,
}

export enum TargetOption {
  BridgeManager = 0,
  GatewayContract = 1,
  BridgeReward = 2,
  BridgeSlash = 3,
  BridgeTracking = 4,
}

export const ballotParamTypes = ['bytes32', 'bytes32', 'uint8'];
export const proposalParamTypes = [
  'bytes32',
  'uint256',
  'uint256',
  'uint256',
  'bytes32',
  'bytes32',
  'bytes32',
  'bytes32',
];
export const globalProposalParamTypes = ['bytes32', 'uint256', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'bytes32'];
export const bridgeOperatorsBallotParamTypes = ['bytes32', 'uint256', 'bytes32'];
export const emergencyExitBallotParamTypes = ['bytes32', 'address', 'address', 'uint256', 'uint256'];

export const BallotTypes = {
  Ballot: [
    { name: 'proposalHash', type: 'bytes32' },
    { name: 'support', type: 'uint8' },
  ],
};

export const ProposalDetailTypes = {
  ProposalDetail: [
    { name: 'chainId', type: 'uint256' },
    { name: 'expiryTimestamp', type: 'uint256' },
    { name: 'targets', type: 'address[]' },
    { name: 'values', type: 'uint256[]' },
    { name: 'calldatas', type: 'bytes[]' },
    { name: 'gasAmounts', type: 'uint256[]' },
  ],
};

export const GlobalProposalTypes = {
  GlobalProposalDetail: [
    { name: 'expiryTimestamp', type: 'uint256' },
    { name: 'targetOptions', type: 'uint8[]' },
    { name: 'values', type: 'uint256[]' },
    { name: 'calldatas', type: 'bytes[]' },
    { name: 'gasAmounts', type: 'uint256[]' },
  ],
};

export const BridgeOperatorsBallotTypes = {
  BridgeOperatorsBallot: [
    { name: 'period', type: 'uint256' },
    { name: 'epoch', type: 'uint256' },
    { name: 'operators', type: 'address[]' },
  ],
};

export const EmergencyExitBallotTypes = {
  EmergencyExitBallot: [
    { name: 'consensusAddress', type: 'address' },
    { name: 'recipientAfterUnlockedFund', type: 'address' },
    { name: 'requestedAt', type: 'uint256' },
    { name: 'expiredAt', type: 'uint256' },
  ],
};

export const getProposalHash = (proposal: ProposalDetailStruct) =>
  keccak256(
    AbiCoder.prototype.encode(proposalParamTypes, [
      proposalTypeHash,
      proposal.nonce,
      proposal.chainId,
      proposal.expiryTimestamp,
      keccak256(
        AbiCoder.prototype.encode(
          proposal.targets.map(() => 'address'),
          proposal.targets
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.values.map(() => 'uint256'),
          proposal.values
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.calldatas.map(() => 'bytes32'),
          proposal.calldatas.map((calldata) => keccak256(calldata))
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.gasAmounts.map(() => 'uint256'),
          proposal.gasAmounts
        )
      ),
    ])
  );

export const getGlobalProposalHash = (proposal: GlobalProposalDetailStruct) =>
  keccak256(
    AbiCoder.prototype.encode(globalProposalParamTypes, [
      globalProposalTypeHash,
      proposal.nonce,
      proposal.expiryTimestamp,
      keccak256(
        AbiCoder.prototype.encode(
          proposal.targetOptions.map(() => 'uint8'),
          proposal.targetOptions
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.values.map(() => 'uint256'),
          proposal.values
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.calldatas.map(() => 'bytes32'),
          proposal.calldatas.map((calldata) => keccak256(calldata))
        )
      ),
      keccak256(
        AbiCoder.prototype.encode(
          proposal.gasAmounts.map(() => 'uint256'),
          proposal.gasAmounts
        )
      ),
    ])
  );

export const getBallotHash = (proposalHash: string, support: BigNumberish) =>
  keccak256(AbiCoder.prototype.encode(ballotParamTypes, [ballotTypeHash, proposalHash, support]));

export const getBallotDigest = (domainSeparator: string, proposalHash: string, support: BigNumberish): string =>
  solidityKeccak256(
    ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
    ['0x19', '0x01', domainSeparator, getBallotHash(proposalHash, support)]
  );

export interface BOsBallot {
  period: BigNumberish;
  epoch: BigNumberish;
  operators: Address[];
}

export const getBOsBallotHash = (period: BigNumberish, epoch: BigNumberish, operators: Address[]) =>
  keccak256(
    AbiCoder.prototype.encode(bridgeOperatorsBallotParamTypes, [
      bridgeOperatorsBallotTypeHash,
      period,
      epoch,
      keccak256(
        AbiCoder.prototype.encode(
          operators.map(() => 'address'),
          operators
        )
      ),
    ])
  );

export const getEmergencyExitBallotHash = (
  consensusAddress: Address,
  recipientAfterUnlockedFund: Address,
  requestedAt: BigNumberish,
  expiredAt: BigNumberish
) =>
  keccak256(
    AbiCoder.prototype.encode(emergencyExitBallotParamTypes, [
      emergencyExitBallotTypehash,
      consensusAddress,
      recipientAfterUnlockedFund,
      requestedAt,
      expiredAt,
    ])
  );

export const getBOsBallotDigest = (
  domainSeparator: string,
  period: BigNumberish,
  epoch: BigNumberish,
  operators: Address[]
): string =>
  solidityKeccak256(
    ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
    ['0x19', '0x01', domainSeparator, getBOsBallotHash(period, epoch, operators)]
  );
