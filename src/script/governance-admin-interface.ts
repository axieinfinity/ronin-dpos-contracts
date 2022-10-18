import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, BytesLike } from 'ethers';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { TypedDataDomain } from '@ethersproject/abstract-signer';
import { AbiCoder, Interface, keccak256, _TypedDataEncoder } from 'ethers/lib/utils';

import { BallotTypes, getProposalHash, VoteType } from './proposal';
import { RoninGovernanceAdmin, TransparentUpgradeableProxyV2__factory } from '../types';
import { ProposalDetailStruct } from '../types/GovernanceAdmin';
import { SignatureStruct } from '../types/MainchainGovernanceAdmin';

export const getGovernanceAdminDomain = (): TypedDataDomain => ({
  name: 'GovernanceAdmin',
  version: '1',
  salt: keccak256(AbiCoder.prototype.encode(['string', 'uint256'], ['RONIN_GOVERNANCE_ADMIN', 2020])),
});

export const calculateGovernanceAdminDomainSeparator = () => _TypedDataEncoder.hashDomain(getGovernanceAdminDomain());

export const mapByteSigToSigStruct = (sig: string): SignatureStruct => {
  const { v, r, s } = ethers.utils.splitSignature(sig);
  return { v, r, s };
};

export class GovernanceAdminInterface {
  signers!: SignerWithAddress[];
  contract!: RoninGovernanceAdmin;
  domain!: TypedDataDomain;
  interface!: Interface;
  address = ethers.constants.AddressZero;

  constructor(contract: RoninGovernanceAdmin, ...signers: SignerWithAddress[]) {
    this.contract = contract;
    this.signers = signers;
    this.address = contract.address;
    this.domain = getGovernanceAdminDomain();
    this.interface = new TransparentUpgradeableProxyV2__factory().interface;
  }

  async createProposal(target: Address, value: BigNumberish, calldata: BytesLike, gasAmount: BigNumberish) {
    const proposal: ProposalDetailStruct = {
      chainId: network.config.chainId!,
      nonce: (await this.contract.round(network.config.chainId!)).add(1),
      targets: [target],
      values: [value],
      calldatas: [calldata],
      gasAmounts: [gasAmount],
    };
    return proposal;
  }

  async generateSignatures(proposal: ProposalDetailStruct) {
    const proposalHash = getProposalHash(proposal);
    const signatures = await Promise.all(
      this.signers.map((v) =>
        v._signTypedData(this.domain, BallotTypes, { proposalHash, support: VoteType.For }).then(mapByteSigToSigStruct)
      )
    );
    return signatures;
  }

  async functionDelegateCall(to: Address, data: BytesLike) {
    const proposal = await this.createProposal(
      to,
      0,
      this.interface.encodeFunctionData('functionDelegateCall', [data]),
      1_000_000
    );
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract.connect(this.signers[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async upgrade(from: Address, to: Address) {
    const proposal = await this.createProposal(from, 0, this.interface.encodeFunctionData('upgradeTo', [to]), 500_000);
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract.connect(this.signers[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }
}
