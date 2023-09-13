import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { checkArraysHaveSameSize } from '../utils';

export type ValidatorCandidateAddressSet = {
  poolAdmin: SignerWithAddress;
  candidateAdmin: SignerWithAddress;
  consensusAddr: SignerWithAddress;
  treasuryAddr: SignerWithAddress;
  bridgeOperator: SignerWithAddress;
};

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
  } else {
    poolAdmins = signers;
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
