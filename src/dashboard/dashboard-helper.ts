import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { ethers } from 'hardhat';
import { AbiCoder, hexStripZeros, keccak256 } from 'ethers/lib/utils';

export function isCorrectContract(contract: Address, expectedContract: Address): boolean {
  if (expectedContract == DEFAULT_ADDRESS) return false;
  return contract.toLocaleLowerCase() == expectedContract.toLocaleLowerCase();
}

export function isCorrectAdmin(admin: Address, expectedAdmin: Address): boolean {
  if (expectedAdmin == DEFAULT_ADDRESS) return false;
  return admin.toLocaleLowerCase() == expectedAdmin.toLocaleLowerCase();
}

export const getAdminOfProxy = async (address: Address): Promise<string> => {
  const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
  const slotValue = await ethers.provider.getStorageAt(address, ADMIN_SLOT);
  return hexStripZeros(slotValue);
};

export const getContractAddress = async (address: Address, contracType: number): Promise<string> => {
  const abiCoder = new AbiCoder();
  const HAS_CONTRACT_SLOT = '0xdea3103d22025c269050bea94c0c84688877f12fa22b7e6d2d5d78a9a49aa1cb';
  const slot = keccak256(abiCoder.encode(['uint8', 'bytes32'], [contracType, HAS_CONTRACT_SLOT]));
  const slotValue = await ethers.provider.getStorageAt(address, slot);
  return hexStripZeros(slotValue);
};

export interface ProxyManagementInfo {
  deployment: Deployment | null;
  address?: Address;
  admin?: Address;
  expectedAdmin?: Address;
  isCorrect?: Boolean;
}
