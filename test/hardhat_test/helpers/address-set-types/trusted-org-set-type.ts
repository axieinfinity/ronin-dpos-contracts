import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { checkArraysHaveSameSize } from '../utils';

export type TrustedOrganizationAddressSet = {
  consensusAddr: SignerWithAddress;
  governor: SignerWithAddress;
  bridgeVoter: SignerWithAddress;
};

export function createTrustedOrganizationAddressSet(
  addrs: SignerWithAddress[]
): TrustedOrganizationAddressSet | undefined {
  if (addrs.length != 3) {
    return;
  }

  return {
    consensusAddr: addrs[0],
    governor: addrs[1],
    bridgeVoter: addrs[2],
  };
}

export function createManyTrustedOrganizationAddressSets(signers: SignerWithAddress[]): TrustedOrganizationAddressSet[];

export function createManyTrustedOrganizationAddressSets(
  consensusAddrs: SignerWithAddress[],
  governors: SignerWithAddress[],
  bridgeVoters: SignerWithAddress[]
): TrustedOrganizationAddressSet[];

export function createManyTrustedOrganizationAddressSets(
  signers: SignerWithAddress[],
  governors?: SignerWithAddress[],
  bridgeVoters?: SignerWithAddress[]
): TrustedOrganizationAddressSet[] {
  let consensusAddrs: SignerWithAddress[] = [];

  if (!governors || !bridgeVoters) {
    expect(signers.length % 3).eq(0, 'createManyTrustedOrganizationAddressSets: signers length must be divisible by 3');

    let _length = signers.length / 3;
    consensusAddrs = signers.splice(0, _length);
    governors = signers.splice(0, _length);
    bridgeVoters = signers.splice(0, _length);
  } else {
    consensusAddrs = signers;
  }

  governors.sort((v1, v2) => v1.address.toLowerCase().localeCompare(v2.address.toLowerCase()));
  bridgeVoters.sort((v1, v2) => v1.address.toLowerCase().localeCompare(v2.address.toLowerCase()));

  expect(checkArraysHaveSameSize([consensusAddrs, governors, bridgeVoters])).eq(
    true,
    'createManyTrustedOrganizationAddressSets: input arrays of signers must have same length'
  );

  return consensusAddrs.map((v, i) => ({
    consensusAddr: v,
    governor: governors![i],
    bridgeVoter: bridgeVoters![i],
  }));
}
