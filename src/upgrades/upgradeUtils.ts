import { BytesLike } from 'ethers';
import { TransparentUpgradeableProxyV2__factory } from '../types';

export const proxyInterface = new TransparentUpgradeableProxyV2__factory().interface;

export const proxyCall = (calldata: BytesLike) => proxyInterface.encodeFunctionData('functionDelegateCall', [calldata]);
