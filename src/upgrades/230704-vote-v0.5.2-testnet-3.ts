/// npx hardhat deploy --tags 230704VoteTestnetV0_5_2__3 --network ronin-testnet

/// Governor who proposes this proposal must manually vote it after running this script.

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyCall, proxyInterface } from './upgradeUtils';
import { VoteType } from '../script/proposal';
import { RoninGatewayV3__factory } from '../types';
import { generalRoninConf, roninchainNetworks } from '../configs/config';
import { network } from 'hardhat';
import { ProposalDetailStruct } from '../types/GovernanceAdmin';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  /// Upgrade contracts

  const RoninGatewayV3LogicDepl = await deployments.get('RoninGatewayV3Logic');
  const RoninGatewayV3Addr = generalRoninConf[network.name]!.bridgeContract;

  const RoninGatewayPauseEnforcerProxy = await deployments.get('RoninGatewayPauseEnforcerProxy');
  const initializeV2_SIG = new RoninGatewayV3__factory().interface.encodeFunctionData('initializeV2');

  const RoninGatewayV3Instr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [RoninGatewayV3LogicDepl.address, initializeV2_SIG]),
    proxyCall(
      new RoninGatewayV3__factory().interface.encodeFunctionData('setEmergencyPauser', [
        RoninGatewayPauseEnforcerProxy.address,
      ])
    ),
  ];

  // const blockNumBefore = await ethers.provider.getBlockNumber();
  // const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  // const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = 1689396507;
  const nonce = 6;

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  // function castProposalVoteForCurrentNetwork(
  //   Proposal.ProposalDetail calldata _proposal,
  //   Ballot.VoteType _support

  let proposal: ProposalDetailStruct = {
    chainId: network.config.chainId!,
    expiryTimestamp: proposalExpiryTimestamp,
    nonce,
    targets: [...RoninGatewayV3Instr.map(() => RoninGatewayV3Addr)], // targets
    values: [...RoninGatewayV3Instr].map(() => 0), // values
    calldatas: [...RoninGatewayV3Instr], // datas
    gasAmounts: [...RoninGatewayV3Instr].map(() => 1_000_000), // gasAmounts
  };

  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'castProposalVoteForCurrentNetwork',
    proposal,
    VoteType.For // ballot type
  );

  console.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

deploy.tags = ['230627VoteTestnetV0_5_2__3'];

export default deploy;
