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

const ROLES = [
  /// @notice reserves 1st bit
  'UNKNOWN_0', // 0
  'UNKNOWN_1', // 1

  'ADMIN', // 2
  'PAUSE_ENFORCER_CONTRACT', // 3
  'COINBASE', // 4
  'BRIDGE_CONTRACT', // 5
  'GOVERNOR', // 6
  'BRIDGE_TRACKING_CONTRACT', // 7
  'CANDIDATE_ADMIN', // 8
  'GOVERNANCE_ADMIN_CONTRACT', // 9
  'WITHDRAWAL_MIGRATOR', // 10
  'MAINTENANCE_CONTRACT', // 11
  'BRIDGE_OPERATOR', // 12
  'SLASH_INDICATOR_CONTRACT', // 13
  'BLOCK_PRODUCER', // 14
  'STAKING_VESTING_CONTRACT', // 15
  'VALIDATOR_CANDIDATE', // 16
  'VALIDATOR_CONTRACT', // 17
  // @notice reserve index for EOA
  'RESERVE_0', // 18
  'STAKING_CONTRACT', // 19
  // @notice reserve index for EOA
  'RESERVE_1', // 20
  'RONIN_TRUSTED_ORGANIZATION_CONTRACT', // 21
];

export const getRoles = (roleName: string): number => {
  return ROLES.indexOf(roleName);
};
