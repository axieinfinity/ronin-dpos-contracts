import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { checkArraysHaveSameSize } from '../utils';

export type OperatorTuple = {
  operator: SignerWithAddress;
  governor: SignerWithAddress;
};

export function createOperatorTuple(addrs: SignerWithAddress[]): OperatorTuple | undefined {
  if (addrs.length != 2) {
    return;
  }

  return {
    operator: addrs[0],
    governor: addrs[1],
  };
}

export function createManyOperatorTuples(signers: SignerWithAddress[]): OperatorTuple[];

export function createManyOperatorTuples(
  operators: SignerWithAddress[],
  governors: SignerWithAddress[]
): OperatorTuple[];

export function createManyOperatorTuples(
  signers: SignerWithAddress[],
  governors?: SignerWithAddress[]
): OperatorTuple[] {
  let operators: SignerWithAddress[] = [];

  if (!governors || !operators) {
    expect(signers.length % 2).eq(0, 'createManyOperatorTuples: signers length must be divisible by 2');

    let _length = signers.length / 2;
    operators = signers.splice(0, _length);
    governors = signers.splice(0, _length);
  } else {
    operators = signers;
  }

  governors.sort((v1, v2) => v1.address.toLowerCase().localeCompare(v2.address.toLowerCase()));
  operators.sort((v1, v2) => v1.address.toLowerCase().localeCompare(v2.address.toLowerCase()));

  expect(checkArraysHaveSameSize([governors, operators])).eq(
    true,
    'createManyOperatorTuples: input arrays of signers must have same length'
  );

  return operators.map((v, i) => ({
    operator: v,
    governor: governors![i],
  }));
}
