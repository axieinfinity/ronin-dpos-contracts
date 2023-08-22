import { expect } from 'chai';
import { TrustedOrganizationAddressSet } from './trusted-org-set-type';
import { ValidatorCandidateAddressSet } from './validator-candidate-set-type';
import { checkArraysHaveSameSize } from '../utils';

export type WhitelistedCandidateAddressSet = TrustedOrganizationAddressSet & ValidatorCandidateAddressSet;

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
