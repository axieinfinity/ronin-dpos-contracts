import { Interface } from '@ethersproject/abi';
import { ethers } from 'ethers';

export class Encoder {
  static readonly abi: string[] = ['function Error(string)'];
  static readonly iface: Interface = new ethers.utils.Interface(Encoder.abi);

  static encodeError(msg: string): string {
    return Encoder.iface.encodeFunctionData('Error', [msg]);
  }
}
