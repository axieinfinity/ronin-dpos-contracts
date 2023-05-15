import { Address } from 'hardhat-deploy/dist/types';

export const verifyAddress = (actual: Address, expected?: Address) => {
  if (actual.toLowerCase() != (expected || '').toLowerCase()) {
    throw Error(`Invalid address, expected=${expected}, actual=${actual}`);
  }
};
