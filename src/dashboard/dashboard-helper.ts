import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { ethers } from 'hardhat';

export function isCorrectAdmin(admin: Address, expectedAdmin: Address): boolean {
  if (expectedAdmin == DEFAULT_ADDRESS) return false;
  return admin.toLocaleLowerCase() == expectedAdmin.toLocaleLowerCase();
}

export const getAdminOfProxy = async (address: Address): Promise<string> => {
  const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
  const slotValue = await ethers.provider.getStorageAt(address, ADMIN_SLOT);
  return ethers.utils.hexStripZeros(slotValue);
};

export interface ProxyManagementInfo {
  deployment: Deployment | null;
  address?: Address;
  admin?: Address;
  expectedAdmin?: Address;
  isCorrect?: Boolean;
}
