import { BigNumber } from 'ethers';

export const DEFAULT_ADDRESS = '0x0000000000000000000000000000000000000000';
export const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';

export const randomBigNumber = () => {
  const hexString = Array.from(Array(64))
    .map(() => Math.round(Math.random() * 0xf).toString(16))
    .join('');
  return BigNumber.from(`0x${hexString}`);
};
