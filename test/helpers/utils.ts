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

const ROLES = {
  UNKNOWN: 0,
  ADMIN: 1,
  GOVERNOR: 2,
  COINBASE: 3,
  CANDIDATE_ADMIN: 4,
  PAUSE_ENFORCER_CONTRACT: 5,
  WITHDRAWAL_MIGRATOR: 6,
  BRIDGE_CONTRACT: 7,
  BRIDGE_OPERATOR: 8,
  BRIDGE_TRACKING_CONTRACT: 9,
  MAINTENANCE_CONTRACT: 10,
  GOVERNANCE_ADMIN_CONTRACT: 11,
  SLASH_INDICATOR_CONTRACT: 12,
  STAKING_CONTRACT: 13,
  STAKING_VESTING_CONTRACT: 14,
  VALIDATOR_CONTRACT: 15,
  VALIDATOR_CANDIDATE: 16,
  BLOCK_PRODUCER: 17,
  RONIN_TRUSTED_ORGANIZATION_CONTRACT: 18,
} as { [key: string]: number };

export const getRoles = (roleName: string): number => {
  return ROLES[roleName];
};
