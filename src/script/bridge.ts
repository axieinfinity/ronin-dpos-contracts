import { AbiCoder, keccak256, _TypedDataEncoder } from 'ethers/lib/utils';

import { InfoStruct, OwnerStruct, ReceiptStruct } from '../types/IMainchainGatewayV3';

// keccak256("TokenInfo(uint8 erc,uint256 id,uint256 quantity)");
const tokenInfoTypeHash = '0x1e2b74b2a792d5c0f0b6e59b037fa9d43d84fbb759337f0112fcc15ca414fc8d';
// keccak256("TokenOwner(address addr,address tokenAddr,uint256 chainId)");
const tokenOwnerTypeHash = '0x353bdd8d69b9e3185b3972e08b03845c0c14a21a390215302776a7a34b0e8764';
// keccak256("Receipt(uint256 id,uint8 kind,TokenOwner mainchain,TokenOwner ronin,TokenInfo info)TokenInfo(uint8 erc,uint256 id,uint256 quantity)TokenOwner(address addr,address tokenAddr,uint256 chainId)");
const receiptTypeHash = '0xb9d1fe7c9deeec5dc90a2f47ff1684239519f2545b2228d3d91fb27df3189eea';

export const tokenInfoParamTypes = ['bytes32', 'uint8', 'uint256', 'uint256'];
export const tokenOwnerParamTypes = ['bytes32', 'address', 'address', 'uint256'];
export const receiptParamTypes = ['bytes32', 'uint256', 'uint8', 'bytes32', 'bytes32', 'bytes32'];

const getTokenInfoHash = (info: InfoStruct): string =>
  keccak256(AbiCoder.prototype.encode(tokenInfoParamTypes, [tokenInfoTypeHash, info.erc, info.id, info.quantity]));

const getTokenOwnerHash = (owner: OwnerStruct): string =>
  keccak256(
    AbiCoder.prototype.encode(tokenOwnerParamTypes, [tokenOwnerTypeHash, owner.addr, owner.tokenAddr, owner.chainId])
  );

export const getReceiptHash = (receipt: ReceiptStruct): string =>
  keccak256(
    AbiCoder.prototype.encode(receiptParamTypes, [
      receiptTypeHash,
      receipt.id,
      receipt.kind,
      getTokenOwnerHash(receipt.mainchain),
      getTokenOwnerHash(receipt.ronin),
      getTokenInfoHash(receipt.info),
    ])
  );
