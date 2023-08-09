import { ethers } from 'ethers';

export const calculateAddress = (from: string, nonce: number) => ({
  nonce,
  address: ethers.utils.getContractAddress({ from, nonce }),
});
