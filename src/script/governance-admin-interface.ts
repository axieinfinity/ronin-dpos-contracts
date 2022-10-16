import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, BytesLike } from 'ethers';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { TypedDataDomain } from '@ethersproject/abstract-signer';
import { AbiCoder, keccak256, _TypedDataEncoder } from 'ethers/lib/utils';

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
  signer!: SignerWithAddress;
  contract!: RoninGovernanceAdmin;
  domain!: TypedDataDomain;
  address = ethers.constants.AddressZero;

  constructor(contract: RoninGovernanceAdmin, signer: SignerWithAddress) {
    this.contract = contract;
    this.signer = signer;
    this.address = contract.address;
    this.domain = getGovernanceAdminDomain();
  }

  private async createProposal(target: Address, value: BigNumberish, calldata: BytesLike, gasAmount: BigNumberish) {
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

  private async generateSignatures(proposal: ProposalDetailStruct) {
    const proposalHash = getProposalHash(proposal);
    const signatures = [
      await this.signer
        ._signTypedData(this.domain, BallotTypes, { proposalHash, support: VoteType.For })
        .then(mapByteSigToSigStruct),
    ];
    return signatures;
  }

  async functionDelegateCall(to: Address, data: BytesLike) {
    const proposal = await this.createProposal(
      to,
      0,
      TransparentUpgradeableProxyV2__factory.connect(to, this.signer).interface.encodeFunctionData(
        'functionDelegateCall',
        [data]
      ),
      1_000_000
    );
    const supports = [VoteType.For];
    const signatures = await this.generateSignatures(proposal);
    return this.contract.connect(this.signer).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async upgrade(from: Address, to: Address) {
    const proposal = await this.createProposal(
      from,
      0,
      TransparentUpgradeableProxyV2__factory.connect(from, this.signer).interface.encodeFunctionData('upgradeTo', [to]),
      500_000
    );
    const supports = [VoteType.For];
    const signatures = await this.generateSignatures(proposal);
    return this.contract.connect(this.signer).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }
}
