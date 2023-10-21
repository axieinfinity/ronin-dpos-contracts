import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { RoninTrustedOrganization__factory, RoninGatewayV3__factory, RoninValidatorSet__factory } from '../../types';
import { generalRoninConf, roninchainNetworks } from '../../configs/config';
import { network } from 'hardhat';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const FastFinalityTrackingProxyDelp = await deployments.get('FastFinalityTrackingProxy');

  // Upgrade Ronin Validator Set Contract
  const RoninValidatorSetProxy = await deployments.get('RoninValidatorSetProxy');
  const RoninValidatorSetLogic = await deployments.get('RoninValidatorSetLogic');
  const RoninValidatorSetInstr = [
    proxyInterface.encodeFunctionData('upgradeToAndCall', [
      RoninValidatorSetLogic.address,
      new RoninValidatorSet__factory().interface.encodeFunctionData('initializeV3', [
        FastFinalityTrackingProxyDelp.address,
      ]),
    ]),
  ];

  console.info('RoninValidatorSetInstr', RoninValidatorSetInstr);

  // Propose the proposal
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  // NOTE: Should double check the RoninGovernanceAdmin address in `deployments` folder is 0x946397deDFd2f79b75a72B322944a21C3240c9c3
  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...RoninValidatorSetInstr.map(() => RoninValidatorSetProxy.address)], // targets
    [...RoninValidatorSetInstr].map(() => 0), // values
    [...RoninValidatorSetInstr], // datas
    [...RoninValidatorSetInstr].map(() => 1_000_000), // gasAmounts
    VoteType.For // ballot type
  );

  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

// yarn hardhat deploy --tags 230907_UpgradeAndInitV3ValidatorSetContract_V0_6_2_testnet --network ronin-testnet
deploy.tags = ['230907_UpgradeAndInitV3ValidatorSetContract_V0_6_2_testnet'];

export default deploy;
