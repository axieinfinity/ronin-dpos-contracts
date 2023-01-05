import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';

export type TrustedOrganizationAddressSet = {
  consensusAddr: SignerWithAddress;
  governor: SignerWithAddress;
  bridgeVoter: SignerWithAddress;
};

export type ValidatorCandidateAddressSet = {
  poolAdmin: SignerWithAddress;
  candidateAdmin: SignerWithAddress;
  consensusAddr: SignerWithAddress;
  treasuryAddr: SignerWithAddress;
  bridgeOperator: SignerWithAddress;
};

export type WhitelistedCandidateAddressSet = TrustedOrganizationAddressSet & ValidatorCandidateAddressSet;

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

export const createValidatorCandidateAddressSet = (
  addrs: SignerWithAddress[]
): ValidatorCandidateAddressSet | undefined => {
  if (addrs.length != 3) {
    return;
  }

  return {
    poolAdmin: addrs[0],
    candidateAdmin: addrs[0],
    treasuryAddr: addrs[0],
    consensusAddr: addrs[1],
    bridgeOperator: addrs[2],
  };
};

export function createManyValidatorCandidateAddressSets(signers: SignerWithAddress[]): ValidatorCandidateAddressSet[];

export function createManyValidatorCandidateAddressSets(
  poolAdmins: SignerWithAddress[],
  candidateAdmins: SignerWithAddress[],
  consensusAddrs: SignerWithAddress[],
  treasuryAddrs: SignerWithAddress[],
  bridgeOperators: SignerWithAddress[]
): ValidatorCandidateAddressSet[];

export function createManyValidatorCandidateAddressSets(
  signers: SignerWithAddress[],
  candidateAdmins?: SignerWithAddress[],
  consensusAddrs?: SignerWithAddress[],
  treasuryAddrs?: SignerWithAddress[],
  bridgeOperators?: SignerWithAddress[]
): ValidatorCandidateAddressSet[] {
  let poolAdmins: SignerWithAddress[] = [];

  if (!candidateAdmins || !consensusAddrs || !treasuryAddrs || !bridgeOperators) {
    expect(signers.length % 3).eq(0, 'createManyValidatorCandidateAddressSets: signers length must be divisible by 3');
    let _length = signers.length / 3;
    poolAdmins = signers.splice(0, _length);
    candidateAdmins = poolAdmins;
    treasuryAddrs = poolAdmins;
    consensusAddrs = signers.splice(0, _length);
    bridgeOperators = signers.splice(0, _length);
  }

  expect(checkArraysHaveSameSize([poolAdmins, candidateAdmins, consensusAddrs, treasuryAddrs, bridgeOperators])).eq(
    true,
    'createManyValidatorCandidateAddressSets: input arrays of signers must have same length'
  );

  return poolAdmins.map((v, i) => ({
    poolAdmin: v,
    candidateAdmin: candidateAdmins![i],
    consensusAddr: consensusAddrs![i],
    treasuryAddr: treasuryAddrs![i],
    bridgeOperator: bridgeOperators![i],
  }));
}

export function mergeToWhitelistedCandidateAddressSet(
  trustedOrg: TrustedOrganizationAddressSet,
  candidate: ValidatorCandidateAddressSet
): WhitelistedCandidateAddressSet {
  candidate.consensusAddr = trustedOrg.consensusAddr;
  return { ...trustedOrg, ...candidate };
}

export function mergeToManyWhitelistedCandidateAddressSets(
  trustedOrgs: TrustedOrganizationAddressSet[],
  candidates: ValidatorCandidateAddressSet[]
): WhitelistedCandidateAddressSet[] {
  expect(checkArraysHaveSameSize([trustedOrgs, candidates])).eq(
    true,
    'mergeToManyWhitelistedCandidateAddressSets: input arrays of signers must have same length'
  );

  return trustedOrgs.map((org, idx) => mergeToWhitelistedCandidateAddressSet(org, candidates[idx]));
}

const checkArraysHaveSameSize = (arrays: Array<any>[]) => {
  let lengths = arrays.map((_) => _.length);
  let uniqueLengths = [...new Set(lengths)];
  return uniqueLengths.length == 1 && uniqueLengths[0] != 0;
};
