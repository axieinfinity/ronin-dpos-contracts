import { BigNumberish } from 'ethers';
import { AbiCoder, keccak256, solidityKeccak256 } from 'ethers/lib/utils';
import { GlobalProposalDetailStruct, ProposalDetailStruct } from '../types/GovernanceAdmin';
import { WeightedAddressStruct } from '../types/IBridge';

// keccak256("ProposalDetail(uint256 nonce,uint256 chainId,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)")
const proposalTypeHash = '0x65526afa953b4e935ecd640e6905741252eedae157e79c37331ee8103c70019d';
// keccak256("GlobalProposalDetail(uint256 nonce,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)")
const globalProposalTypeHash = '0xdb316eb400de2ddff92ab4255c0cd3cba634cd5236b93386ed9328b7d822d1c7';
// keccak256("Ballot(bytes32 proposalHash,uint8 support)")
const ballotTypeHash = '0xd900570327c4c0df8dd6bdd522b7da7e39145dd049d2fd4602276adcd511e3c2';
// keccak256("BridgeOperatorsBallot(uint256 period,BridgeOperator[] operators)BridgeOperator(address addr,uint256 weight)");
const bridgeOperatorsBallotTypeHash = '0x086d287088869477577720f66bf2a8412510e726fd1a893739cf6c2280aadcb5';
// keccak256("BridgeOperator(address addr,uint256 weight)");
const bridgeOperatorTypeHash = '0xe71132f1797176c8456299d5325989bbf16523f1e2e3aef4554d23f982955a2c';

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

export const ballotParamTypes = ['bytes32', 'bytes32', 'uint8'];
export const proposalParamTypes = ['bytes32', 'uint256', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'bytes32'];
export const globalProposalParamTypes = ['bytes32', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'bytes32'];
export const bridgeOperatorsBallotParamTypes = ['bytes32', 'uint256', 'bytes32'];
export const bridgeOperatorParamTypes = ['bytes32', 'address', 'uint256'];

export const BallotTypes = {
  Ballot: [
    { name: 'proposalHash', type: 'bytes32' },
    { name: 'support', type: 'uint8' },
  ],
};

export const ProposalDetailTypes = {
  ProposalDetail: [
    { name: 'chainId', type: 'uint256' },
    { name: 'targets', type: 'address[]' },
    { name: 'values', type: 'uint256[]' },
    { name: 'calldatas', type: 'bytes[]' },
    { name: 'gasAmounts', type: 'uint256[]' },
  ],
};

export const GlobalProposalTypes = {
  GlobalProposalDetail: [
    { name: 'targetOptions', type: 'uint8[]' },
    { name: 'values', type: 'uint256[]' },
    { name: 'calldatas', type: 'bytes[]' },
    { name: 'gasAmounts', type: 'uint256[]' },
  ],
};

export const BridgeOperatorsBallotTypes = {
  BridgeOperatorsBallot: [
    { name: 'period', type: 'uint256' },
    { name: 'operators', type: 'BridgeOperator[]' },
  ],
  BridgeOperator: [
    { name: 'addr', type: 'address' },
    { name: 'weight', type: 'uint256' },
  ],
};

export const getProposalHash = (proposal: ProposalDetailStruct) =>
  keccak256(
    AbiCoder.prototype.encode(proposalParamTypes, [
      proposalTypeHash,
      proposal.nonce,
      proposal.chainId,
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
  operators: WeightedAddressStruct[];
}

export const getBOsBallotHash = (period: BigNumberish, operators: WeightedAddressStruct[]) =>
  keccak256(
    AbiCoder.prototype.encode(bridgeOperatorsBallotParamTypes, [
      bridgeOperatorsBallotTypeHash,
      period,
      keccak256(
        AbiCoder.prototype.encode(
          operators.map(() => 'bytes32'),
          operators.map(({ addr, weight }) =>
            keccak256(AbiCoder.prototype.encode(bridgeOperatorParamTypes, [bridgeOperatorTypeHash, addr, weight]))
          )
        )
      ),
    ])
  );

export const getBOsBallotDigest = (
  domainSeparator: string,
  period: BigNumberish,
  operators: WeightedAddressStruct[]
): string =>
  solidityKeccak256(
    ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
    ['0x19', '0x01', domainSeparator, getBOsBallotHash(period, operators)]
  );
