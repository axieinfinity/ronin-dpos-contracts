import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, BigNumberish, BytesLike } from 'ethers';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { TypedDataDomain } from '@ethersproject/abstract-signer';
import { AbiCoder, Interface, keccak256, _TypedDataEncoder } from 'ethers/lib/utils';

import { BallotTypes, getProposalHash, VoteType } from './proposal';
import { RoninGovernanceAdmin, TransparentUpgradeableProxyV2__factory } from '../types';
import { ProposalDetailStruct } from '../types/GovernanceAdmin';
import { SignatureStruct } from '../types/MainchainGovernanceAdmin';
import { RoninGovernanceAdminArguments } from '../utils';
import { getLastBlockTimestamp } from '../../test/hardhat_test/helpers/utils';
import { defaultTestConfig } from '../../test/hardhat_test/helpers/fixture';

export const getGovernanceAdminDomain = (roninChainId: BigNumberish): TypedDataDomain => ({
  name: 'GovernanceAdmin',
  version: '3',
  salt: keccak256(AbiCoder.prototype.encode(['string', 'uint256'], ['RONIN_GOVERNANCE_ADMIN', roninChainId])),
});

export const calculateGovernanceAdminDomainSeparator = (roninChainId: BigNumberish) =>
  _TypedDataEncoder.hashDomain(getGovernanceAdminDomain(roninChainId));

export const mapByteSigToSigStruct = (sig: string): SignatureStruct => {
  const { v, r, s } = ethers.utils.splitSignature(sig);
  return { v, r, s };
};

export class GovernanceAdminInterface {
  signers!: SignerWithAddress[];
  contract!: RoninGovernanceAdmin;
  domain!: TypedDataDomain;
  interface!: Interface;
  args!: RoninGovernanceAdminArguments;
  address = ethers.constants.AddressZero;

  constructor(
    contract: RoninGovernanceAdmin,
    roninChainId: BigNumberish,
    args?: RoninGovernanceAdminArguments,
    ...signers: SignerWithAddress[]
  ) {
    this.contract = contract;
    this.signers = signers;
    this.address = contract.address;
    this.domain = getGovernanceAdminDomain(roninChainId);
    this.args = args ?? defaultTestConfig?.governanceAdminArguments!;
    this.interface = new TransparentUpgradeableProxyV2__factory().interface;
  }

  async createProposal(
    expiryTimestamp: BigNumberish,
    target: Address,
    value: BigNumberish,
    calldata: BytesLike,
    gasAmount: BigNumberish,
    nonce?: BigNumber
  ) {
    const proposal: ProposalDetailStruct = {
      chainId: network.config.chainId!,
      expiryTimestamp,
      nonce: nonce ?? (await this.contract.round(network.config.chainId!)).add(1),
      targets: [target],
      values: [value],
      calldatas: [calldata],
      gasAmounts: [gasAmount],
    };
    return proposal;
  }

  async generateSignatures(proposal: ProposalDetailStruct, signers?: SignerWithAddress[], support?: VoteType) {
    const proposalHash = getProposalHash(proposal);
    const signatures = await Promise.all(
      (signers ?? this.signers).map((v) =>
        v
          ._signTypedData(this.domain, BallotTypes, { proposalHash, support: support ?? VoteType.For })
          .then(mapByteSigToSigStruct)
      )
    );
    return signatures;
  }

  async defaultExpiryTimestamp() {
    let latestTimestamp = await getLastBlockTimestamp();
    return BigNumber.from(this.args.proposalExpiryDuration!).add(latestTimestamp);
  }

  async functionDelegateCall(to: Address, data: BytesLike) {
    const proposal = await this.createProposal(
      await this.defaultExpiryTimestamp(),
      to,
      0,
      this.interface.encodeFunctionData('functionDelegateCall', [data]),
      2_000_000
    );
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract.connect(this.signers[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async functionDelegateCalls(toList: Address[], dataList: BytesLike[]) {
    if (toList.length != dataList.length || toList.length == 0) {
      throw Error('invalid array length');
    }

    const proposal = {
      chainId: network.config.chainId!,
      expiryTimestamp: await this.defaultExpiryTimestamp(),
      nonce: (await this.contract.round(network.config.chainId!)).add(1),
      targets: toList,
      values: toList.map(() => 0),
      calldatas: dataList.map((v) => this.interface.encodeFunctionData('functionDelegateCall', [v])),
      gasAmounts: toList.map(() => 2_000_000),
    };

    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract.connect(this.signers[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async upgrade(from: Address, to: Address) {
    const proposal = await this.createProposal(
      await this.defaultExpiryTimestamp(),
      from,
      0,
      this.interface.encodeFunctionData('upgradeTo', [to]),
      500_000
    );
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract.connect(this.signers[0]).proposeProposalStructAndCastVotes(proposal, supports, signatures);
  }
}
