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
// keccak256("BridgeOperatorsBallot(uint256 period,address[] operators)");
const bridgeOperatorsBallotTypeHash = '0xeea5e3908ac28cbdbbce8853e49444c558a0a03597e98ef19e6ff86162ed9ae3';

export enum VoteType {
  For = 0,
  Against = 1,
}

export enum VoteStatus {
  Pending = 0,
  Approved = 1,
  Executed = 2,
  Rejected = 3,
  Expired = 4,
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
    { name: 'operators', type: 'address[]' },
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
  operators: Address[];
}

export const getBOsBallotHash = (period: BigNumberish, operators: Address[]) =>
  keccak256(
    AbiCoder.prototype.encode(bridgeOperatorsBallotParamTypes, [
      bridgeOperatorsBallotTypeHash,
      period,
      keccak256(
        AbiCoder.prototype.encode(
          operators.map(() => 'address'),
          operators
        )
      ),
    ])
  );

export const getBOsBallotDigest = (domainSeparator: string, period: BigNumberish, operators: Address[]): string =>
  solidityKeccak256(
    ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
    ['0x19', '0x01', domainSeparator, getBOsBallotHash(period, operators)]
  );
