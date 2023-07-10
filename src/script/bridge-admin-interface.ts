import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, BigNumberish, BytesLike } from 'ethers';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';
import { TypedDataDomain } from '@ethersproject/abstract-signer';
import { AbiCoder, Interface, keccak256, _TypedDataEncoder } from 'ethers/lib/utils';

import { BallotTypes, getGlobalProposalHash, getProposalHash, TargetOption, VoteType } from './proposal';
import { RoninBridgeManager, TransparentUpgradeableProxyV2__factory } from '../types';
import { GlobalProposalDetailStruct, SignatureStruct } from '../types/MainchainBridgeManager';
import { getLastBlockTimestamp } from '../../test/helpers/utils';
import { defaultTestConfig } from '../../test/helpers/fixture';
import { BridgeManagerArguments } from '../../src/configs/bridge-manager';

export const getBridgeManagerDomain = (roninChainId: BigNumberish): TypedDataDomain => ({
  name: 'BridgeAdmin',
  version: '2',
  salt: keccak256(AbiCoder.prototype.encode(['string', 'uint256'], ['BRIDGE_ADMIN', roninChainId])),
});

export const calculateBridgeManagerDomainSeparator = (roninChainId: BigNumberish) =>
  _TypedDataEncoder.hashDomain(getBridgeManagerDomain(roninChainId));

export const mapByteSigToSigStruct = (sig: string): SignatureStruct => {
  const { v, r, s } = ethers.utils.splitSignature(sig);
  return { v, r, s };
};

export class BridgeManagerInterface {
  signers!: SignerWithAddress[];
  contract!: RoninBridgeManager;
  domain!: TypedDataDomain;
  interface!: Interface;
  args!: BridgeManagerArguments;
  address = ethers.constants.AddressZero;

  constructor(
    contract: RoninBridgeManager,
    roninChainId: BigNumberish,
    args?: BridgeManagerArguments,
    ...signers: SignerWithAddress[]
  ) {
    this.contract = contract;
    this.signers = signers;
    this.address = contract.address;
    this.domain = getBridgeManagerDomain(roninChainId);
    this.args = args ?? defaultTestConfig?.bridgeManagerArguments!;
    this.interface = new TransparentUpgradeableProxyV2__factory().interface;
  }

  async createProposal(
    expiryTimestamp: BigNumberish,
    targetOption: TargetOption,
    value: BigNumberish,
    calldata: BytesLike,
    gasAmount: BigNumberish,
    nonce?: BigNumber
  ) {
    const proposal: GlobalProposalDetailStruct = {
      expiryTimestamp,
      nonce: nonce ?? (await this.contract.round(network.config.chainId!)).add(1),
      targetOptions: [targetOption],
      values: [value],
      calldatas: [calldata],
      gasAmounts: [gasAmount],
    };
    return proposal;
  }

  async generateSignatures(proposal: GlobalProposalDetailStruct, signers?: SignerWithAddress[], support?: VoteType) {
    const proposalHash = getGlobalProposalHash(proposal);
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
    return BigNumber.from(this.args.expiryDuration!).add(latestTimestamp);
  }

  async functionDelegateCall(targetOption: TargetOption, data: BytesLike) {
    const proposal = await this.createProposal(
      await this.defaultExpiryTimestamp(),
      targetOption,
      0,
      this.interface.encodeFunctionData('functionDelegateCall', [data]),
      2_000_000
    );
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract
      .connect(this.signers[0])
      .proposeGlobalProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async functionDelegateCalls(targetOptionsList: TargetOption[], dataList: BytesLike[]) {
    if (targetOptionsList.length != dataList.length || targetOptionsList.length == 0) {
      throw Error('invalid array length');
    }

    const proposal: GlobalProposalDetailStruct = {
      expiryTimestamp: await this.defaultExpiryTimestamp(),
      nonce: (await this.contract.round(network.config.chainId!)).add(1),
      values: targetOptionsList.map(() => 0),
      targetOptions: targetOptionsList,
      calldatas: dataList.map((v) => this.interface.encodeFunctionData('functionDelegateCall', [v])),
      gasAmounts: targetOptionsList.map(() => 2_000_000),
    };

    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    console.log('signer propose', this.signers[0].address);
    return this.contract
      .connect(this.signers[0])
      .proposeGlobalProposalStructAndCastVotes(proposal, supports, signatures);
  }

  async upgrade(targetOption: TargetOption, to: Address) {
    const proposal = await this.createProposal(
      await this.defaultExpiryTimestamp(),
      targetOption,
      0,
      this.interface.encodeFunctionData('upgradeTo', [to]),
      500_000
    );
    const signatures = await this.generateSignatures(proposal);
    const supports = signatures.map(() => VoteType.For);
    return this.contract
      .connect(this.signers[0])
      .proposeGlobalProposalStructAndCastVotes(proposal, supports, signatures);
  }
}
