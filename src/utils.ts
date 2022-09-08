import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { Interface, LogDescription } from 'ethers/lib/utils';

export const DEFAULT_ADDRESS = '0x0000000000000000000000000000000000000000';
export const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';

export const randomBigNumber = () => {
  const hexString = Array.from(Array(64))
    .map(() => Math.round(Math.random() * 0xf).toString(16))
    .join('');
  return BigNumber.from(`0x${hexString}`);
};

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
