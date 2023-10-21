/// npx hardhat deploy --tags 230411AddGVs --network ronin-mainnet

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { VoteType } from '../script/proposal';
import { RoninTrustedOrganization__factory } from '../types';
import { explorerUrl, proxyCall } from './upgradeUtils';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const trustedOrgProxy = await deployments.get('RoninTrustedOrganizationProxy');
  const trustedOrgInterface = new RoninTrustedOrganization__factory().interface;

  const orgs = [
    {
      name: 'Stable Node',
      consensus: '0x6e46924371d0e910769aabe0d867590deac20684',
      admin: '0xAaf13f99BDBF3bFa9209AaBFcd74C50c6D1A9e72',
      governor: '0xea172676e4105e92cc52dbf45fd93b274ec96676',
      bridge: '0xF4ed08C347E63e00916aF33eb2B371eEA9812593',
    },
    {
      name: 'DappRadar',
      consensus: '0x8eec4f1c0878f73e8e09c1be78ac1465cc16544d',
      admin: '0x8Eec4F1c0878F73E8e09C1be78aC1465Cc16544D',
      governor: '0x90ead0e8d5f5bf5658a2e6db04535679df0f8e43',
      bridge: '0x0eCeE7D75D4d00d68fb4df5bC62E6D09E7EC014d',
    },
    {
      name: 'Nonfungible',
      consensus: '0xee11d2016e9f2fae606b2f12986811f4abbe6215',
      admin: '0x6133f1ee848df0dc45abc3eb92b7627f667ae00f',
      governor: '0x77ab649caa7b4b673c9f2cf069900df48114d79d',
      bridge: '0x5153545192d793ff3dda1075196365f2f82e5264',
    },
    {
      name: 'Animoca Brands',
      consensus: '0x210744c64eea863cf0f972e5aebc683b98fb1984',
      admin: '0xd8fcc2bc2da24e7d74af0078408e6394d7080776',
      governor: '0x4620fb95eabdab4bf681d987e116e0aaef1adef2',
      bridge: '0x0e28a9df6979952ab333567917f4da22069a8255',
    },
    {
      name: 'AxieChat',
      consensus: '0xd11d9842babd5209b9b1155e46f5878c989125b7',
      admin: '0x2d593A0087029501eE419b9415DeC3fAC195FE4A',
      governor: '0x5832c3219c1da998e828e1a2406b73dbfc02a70c',
      bridge: '0xc18e7b56684903f0c8ba900e42f4aac406882b9b',
    },
    {
      name: 'Nansen',
      consensus: '0xfc3e31519b551bd594235dd0ef014375a87c4e21',
      admin: '0x4abd99f9f4798C9536dAc5594a5b16916DF300b9',
      governor: '0x60c4b72fc62b3e3a74e283aa9ba20d61dd4d8f1b',
      bridge: '0x7b8325312dfF80B10e03D3f764c9472CEcE83A96',
    },
    {
      name: 'Community Gaming',
      consensus: '0x9b959d27840a31988410ee69991bcf0110d61f02',
      admin: '0x2C150A17292fd376CDaE6e6c01d5a99134A1F7f4',
      governor: '0xbacb04ea617b3e5eee0e3f6e8fcb5ba886b83958',
      bridge: '0x452273E252F96Eb9dc098FaeDc9e8a947986336B',
    },
    {
      name: 'YGG',
      consensus: '0xe07d7e56588a6fd860c5073c70a099658c060f3d',
      admin: '0x4B18CEBEB9797Ea594b5977109cc07b21c37E8c3',
      governor: '0xD5877c63744903a459CCBa94c909CDaAE90575f8',
      bridge: '0x139eeA2007De5917752dB8c6325c19e6e1E4956d',
    },
    {
      name: 'QU3ST',
      consensus: '0xec702628f44c31acc56c3a59555be47e1f16eb1e',
      admin: '0x0edb20dd5fe4f2e6ac3f58f304ac071273893888',
      governor: '0xe258f9996723b910712d6e67ada4eafc15f7f101',
      bridge: '0x8fe8fe3dff9a6ee301fd061128f7593bc233c4cb',
    },
    {
      name: 'Coco__Bear',
      consensus: '0x52349003240770727900b06a3b3a90f5c0219ade',
      admin: '0xcea3d996cf38120fa7a736e687f2f7306dfb0034',
      governor: '0x02201f9bfd2face1b9f9d30d776e77382213da1a',
      bridge: '0x573e3028958c457c418173a60668491455786afb',
    },
    {
      name: 'Google',
      consensus: '0x32d619dc6188409cebbc52f921ab306f07db085b',
      admin: '0x4e0a599e4dff57965e0dd5bc680f43cc864364c2',
      governor: '0x58aBcBCAb52dEE942491700CD0DB67826BBAA8C6',
      bridge: '0x66bc2886b4bf8b1fd434b83b77af32e3579a01ea',
    },
  ];

  const trustedOrgInstructions = [
    proxyCall(
      trustedOrgInterface.encodeFunctionData('addTrustedOrganizations', [
        orgs.map((_) => ({
          consensusAddr: _.consensus,
          governor: _.governor,
          bridgeVoter: _.bridge,
          weight: 100,
          addedBlock: 0,
        })),
      ])
    ),
  ];

  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeGlobal',
    proposalExpiryTimestamp, // expiryTimestamp
    trustedOrgInstructions.map(() => 0), // _targetOptions
    trustedOrgInstructions.map(() => 0), // values
    trustedOrgInstructions, // datas
    trustedOrgInstructions.map(() => 2_000_000) // gasAmounts
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230411AddGVs'];

export default deploy;
