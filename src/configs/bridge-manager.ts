import { BigNumber, BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../utils';
import { Address } from 'hardhat-deploy/dist/types';
import { TargetOption } from '../script/proposal';

export type BridgeManagerMemberStruct = {
  governor: Address;
  operator: Address;
  weight: BigNumberish;
};

export type TargetOptionStruct = {
  option: TargetOption;
  target: Address;
};

export interface BridgeManagerArguments {
  numerator?: BigNumberish;
  denominator?: BigNumberish;
  expiryDuration?: BigNumberish;
  members?: BridgeManagerMemberStruct[];
  targets?: TargetOptionStruct[];
}

export interface BridgeManagerConfig {
  [network: LiteralNetwork]: undefined | BridgeManagerArguments;
}

const rep2MemberMainnetTemp: BridgeManagerMemberStruct[] = [
  {
    operator: '0x32015E8B982c61bc8a593816FdBf03A603EEC823',
    governor: '0x3200A8eb56767c3760e108Aa27C65bfFF036d8E6',
    weight: 100,
  },
];
const rep2MembersMainnet: BridgeManagerMemberStruct[] = [
  {
    operator: '0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA',
    governor: '0xe880802580a1fbdef67ace39d1b21c5b2c74f059',
  },
  {
    operator: '0x4a4217d8751a027D853785824eF40522c512A3Fe',
    governor: '0x4b18cebeb9797ea594b5977109cc07b21c37e8c3',
  },
  {
    operator: '0x32cB6da260726BB2192c4085B857aFD945A215Cb',
    governor: '0xa441f1399c8c023798586fbbbcf35f27279638a1',
  },
  {
    operator: '0xA91D05b7c6e684F43E8Fe0c25B3c4Bb1747A2a9E',
    governor: '0x72a69b04b59c36fced19ac54209bef878e84fcbf',
  },
  {
    operator: '0xe38aFbE7738b6Ec4280A6bCa1176c1C1A928A19C',
    governor: '0xe258f9996723b910712d6e67ada4eafc15f7f101',
  },
  {
    operator: '0xE795F18F2F5DF5a666994e839b98263Dba86C902',
    governor: '0x020dd9a5e318695a61dda88db7ad077ec306e3e9',
  },
  {
    operator: '0x772112C7e5dD4ed663e844e79d77c1569a2E88ce',
    governor: '0x2d593A0087029501eE419b9415DeC3fAC195FE4A',
  },
  {
    operator: '0xF0c48B7F020BB61e6A3500AbC4b4954Bde7A2039',
    governor: '0x9b0612e43855ef9a7c329ee89653ba45273b550e',
  },
  {
    operator: '0x063105D0E7215B703909a7274FE38393302F3134',
    governor: '0x47cfcb64f8ea44d6ea7fab32f13efa2f8e65eec1',
  },
  {
    operator: '0xD9d5b3E58fa693B468a20C716793B18A1195380a',
    governor: '0xad23e87306aa3c7b95ee760e86f40f3021e5fa18',
  },
  {
    operator: '0xff30Ed09E3AE60D39Bce1727ee3292fD76A6FAce',
    governor: '0xbacb04ea617b3e5eee0e3f6e8fcb5ba886b83958',
  },
  {
    operator: '0x8c4AD2DC12AdB9aD115e37EE9aD2e00E343EDf85',
    governor: '0x77ab649caa7b4b673c9f2cf069900df48114d79d',
  },
  {
    operator: '0x73f5B22312B7B2B3B1Cd179fC62269aB369c8206',
    governor: '0x0dca20728c8bb7173d3452559f40e95c60915799',
  },
  {
    operator: '0x5e04DC8156ce222289d52487dbAdCb01C8c990f9',
    governor: '0x0d48adbdc523681c0dee736dbdc4497e02bec210',
  },
  {
    operator: '0x564DcB855Eb360826f27D1Eb9c57cbbe6C76F50F',
    governor: '0xea172676e4105e92cc52dbf45fd93b274ec96676',
  },
  {
    operator: '0xEC5c90401F95F8c49b1E133E94F09D85b21d96a4',
    governor: '0xed448901cc62be10c5525ba19645ddca1fd9da1d',
  },
  {
    operator: '0x332253265e36689D9830E57112CD1aaDB1A773f9',
    governor: '0x8d4f4e4ba313c4332e720445d8268e087d5c19b8',
  },
  {
    operator: '0x236aF2FFdb611B14e3042A982d13EdA1627d9C96',
    governor: '0x58aBcBCAb52dEE942491700CD0DB67826BBAA8C6',
  },
  {
    operator: '0x54C8C42F07007D43c3049bEF6f10eA68687d43ef',
    governor: '0x4620fb95eabdab4bf681d987e116e0aaef1adef2',
  },
  {
    operator: '0x66225AcC78Be789C57a11C9a18F051C779d678B5',
    governor: '0xc092fa0c772b3c850e676c57d8737bb39084b9ac',
  },
  {
    operator: '0xf4682B9263d1ba9bd9Db09dA125708607d1eDd3a',
    governor: '0x60c4b72fc62b3e3a74e283aa9ba20d61dd4d8f1b',
  },
  {
    operator: '0xc23F2907Bc11848B5d5cEdBB835e915D7b760d99',
    governor: '0xed3805fb65ff51a99fef4676bdbc97abeca93d11',
  },
].map((member) => {
  return { ...member, weight: 100 };
});

export const bridgeManagerConf: BridgeManagerConfig = {
  [Network.Hardhat]: undefined,
  [Network.Goerli]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa',
        operator: '0x2e82D2b56f858f79DeeF11B160bFC4631873da2B',
        weight: 100,
      },
      {
        governor: '0xb033ba62EC622dC54D0ABFE0254e79692147CA26',
        operator: '0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb',
        weight: 100,
      },
      {
        governor: '0x087D08e3ba42e64E3948962dd1371F906D1278b9',
        operator: '0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c',
        weight: 100,
      },
      {
        governor: '0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F',
        operator: '0xcc5fc5b6c8595f56306da736f6cd02ed9141c84a',
        weight: 100,
      },
    ],
  },
  [Network.Testnet]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: [
      {
        governor: '0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa',
        operator: '0x2e82D2b56f858f79DeeF11B160bFC4631873da2B',
        weight: 100,
      },
      {
        governor: '0xb033ba62EC622dC54D0ABFE0254e79692147CA26',
        operator: '0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb',
        weight: 100,
      },
      {
        governor: '0x087D08e3ba42e64E3948962dd1371F906D1278b9',
        operator: '0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c',
        weight: 100,
      },
      {
        governor: '0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F',
        operator: '0xcc5fc5b6c8595f56306da736f6cd02ed9141c84a',
        weight: 100,
      },
    ],
  },
  [Network.Mainnet]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: rep2MembersMainnet,
    // members: rep2MemberMainnetTemp,
  },
  [Network.Ethereum]: {
    numerator: 70,
    denominator: 100,
    expiryDuration: 14 * 86400, // 14 days
    members: rep2MembersMainnet,
    // members: rep2MemberMainnetTemp,
  },
};

export interface BridgeRewardArguments {
  rewardPerPeriod?: BigNumberish;
  topupAmount?: BigNumberish;
}
export interface BridgeRewardConfig {
  [network: LiteralNetwork]: BridgeRewardArguments | undefined;
}

const defaultBridgeRewardConf: BridgeRewardArguments = {
  rewardPerPeriod: BigNumber.from(10).pow(18), // 1 RON per block
};

export const bridgeRewardConf: BridgeRewardConfig = {
  [Network.Hardhat]: undefined,
  [Network.Local]: defaultBridgeRewardConf,
  [Network.Devnet]: defaultBridgeRewardConf,
  [Network.Testnet]: {
    rewardPerPeriod: BigNumber.from(10).pow(18), // 1 RON per period,
    topupAmount: BigNumber.from(10).pow(18).mul(1_000_000), // 1M RON
  },
  [Network.Mainnet]: {
    rewardPerPeriod: BigNumber.from('2739726027397260273972'), // (1M/365) ~ 2739.7260 RON per period,
    topupAmount: 0,
  },
};
