import { BigNumberish } from 'ethers';
import { LiteralNetwork, Network } from '../addresses';

interface DPoStakingConf {
  [network: LiteralNetwork]:
    | {
        validatorContract: BigNumberish;
        governanceAdminContract: BigNumberish;
        maxValidatorCandidate: BigNumberish;
        minValidatorBalance: BigNumberish;
      }
    | undefined;
}

// TODO: update config for testnet & mainnet
export const stakingConfig: DPoStakingConf = {
  [Network.Hardhat]: undefined,
  [Network.Testnet]: undefined,
  [Network.Mainnet]: undefined,
};
