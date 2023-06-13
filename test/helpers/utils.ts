import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { Interface, LogDescription } from 'ethers/lib/utils';
import { ethers, network } from 'hardhat';
import { Address } from 'hardhat-deploy/dist/types';

export const expectEvent = async (
  contractInterface: Interface,
  eventName: string,
  tx: ContractTransaction,
  expectFn: (log: LogDescription) => void,
  eventNumbers?: number
) => {
  const receipt = await tx.wait();
  const topic = contractInterface.getEventTopic(eventName);
  let counter = 0;

  for (let i = 0; i < receipt.logs.length; i++) {
    const eventLog = receipt.logs[i];
    if (eventLog.topics[0] == topic) {
      counter++;
      const event = contractInterface.parseLog(eventLog);
      expectFn(event);
    }
  }

  expect(counter, 'invalid number of emitted events').eq(eventNumbers);
};

export const mineDummyBlock = () => network.provider.send('hardhat_mine', []);

export const mineBatchTxs = async (fn: () => Promise<void>) => {
  await network.provider.send('evm_setAutomine', [false]);
  await fn();
  await network.provider.send('evm_mine');
  await network.provider.send('evm_setAutomine', [true]);
  await mineDummyBlock();
};

export const getLastBlockTimestamp = async (): Promise<number> => {
  let blockNumBefore = await ethers.provider.getBlockNumber();
  let blockBefore = await ethers.provider.getBlock(blockNumBefore);
  return blockBefore.timestamp;
};

export const calculateAddress = (from: Address, nonce: number) => ({
  nonce,
  address: ethers.utils.getContractAddress({ from, nonce }),
});

export const compareAddrs = (firstStr: string, secondStr: string) =>
  firstStr.toLowerCase().localeCompare(secondStr.toLowerCase());

export const accessControlRevertStr = (addr: Address, role: string): string =>
  `AccessControl: account ${addr.toLocaleLowerCase()} is missing role ${role}`;

export const compareBigNumbers = (firstBigNumbers: BigNumber[], secondBigNumbers: BigNumber[]) =>
  expect(firstBigNumbers.map((_) => _.toHexString())).deep.equal(secondBigNumbers.map((_) => _.toHexString()));

const CONTRACT_TYPE = [
  /*  0 */ 'UNKNOWN',
  /*  1 */ 'PAUSE_ENFORCER_CONTRACT',
  /*  2 */ 'BRIDGE_CONTRACT',
  /*  3 */ 'BRIDGE_TRACKING_CONTRACT',
  /*  4 */ 'GOVERNANCE_ADMIN_CONTRACT',
  /*  5 */ 'MAINTENANCE_CONTRACT',
  /*  6 */ 'SLASH_INDICATOR_CONTRACT',
  /*  7 */ 'STAKING_VESTING_CONTRACT',
  /*  8 */ 'VALIDATOR_CONTRACT',
  /*  9 */ 'STAKING_CONTRACT',
  /* 10 */ 'RONIN_TRUSTED_ORGANIZATION_CONTRACT',
  /* 11 */ 'PROFILE_CONTRACT',
];

export const getRole = (roleName: string): number => {
  return CONTRACT_TYPE.indexOf(roleName);
};

export const getProxyImplementation = async (proxy: string): Promise<string> =>
  '0x' +
  (
    await ethers.provider.getStorageAt(
      proxy,
      /// @dev value is equal to keccak256("eip1967.proxy.implementation") - 1
      '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
    )
  ).slice(-40);

export const getProxyAdmin = async (proxy: string): Promise<string> =>
  '0x' +
  (
    await ethers.provider.getStorageAt(
      proxy,
      /// @dev value is equal to keccak256("eip1967.proxy.admin") - 1
      '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103'
    )
  ).slice(-40);
