# Ronin DPoS Contracts

The next version of smart contracts that power Ronin DPoS network.

_NOTE: This smart contract version does not includes method to prevent the 51% attack. It is not finalized at the implementation time._

- [Overview](#ronin-dpos-contracts)
  - [Staking contract](#staking-contract)
    - [Validator Candidate](#validator-candidate)
    - [Delegator](#delegator)
    - [Reward Calculation](#reward-calculation)
  - [Validator Contract](#validator-contract)
  - [Slashing](#slashing)
  - [Contract Interaction flow](#contract-interaction-flow)
- [Development](#development)
  - [Requirement](#requirement)
  - [Compile & test](#compile---test)
- [Deployment](#deployment)

## Staking contract

An user can propose themselves to be a validator candidate by staking their RON. Other users are allowed to register as delegators by staking any amount of RON to the staking contract, he/she can choose a validator to stake their coins.

The ones on top `N` users with the highest amount of staked coins will become validators.

### Validator Candidate

**Proposing validator**

| Params                   | Explanation                                                                                  |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| `uint256 commissionRate` | The rate to share for the validator. Values in range [0; 100_00] stands for [0; 100%]        |
| `address consensusAddr`  | Address to produce block                                                                     |
| `address treasuryAddr`   | Address to receive block reward                                                              |
| `msg.value`              | The amount of RON to stake, require to be larger than the minimum RON threshold to be validator |

The validator candidates can deposit or withdraw their funds afterwards as long as the staking balance must be greater than the minimum RON threshold.

**Renounce validator**

The candidates can renounce the validator propose and take back their deposited RON.

### Delegator

The delegator can choose the validator to stake and receive the commission reward:

| Methods                                                   | Explanation                                                                        |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `delegate(consensusAddr)`                                 | Stakes `msg.value` amount of RON for a validator `consensusAddr`                   |
| `undelegate(consensusAddr, amount)`                       | Unstakes from a validator                                                          |
| `redelegate(consensusAddrSrc, consensusAddrDst, amount)`  | Unstakes `amount` RON from the `consensusAddrSrc` and stake for `consensusAddrDst` |
| `getRewards()`                                            | Returns the pending rewards and the claimable rewards                              |
| `claimRewards(consensusAddrList)`                         | Claims all the reward from the validators                                          |
| `delegatePendingReward(consensusAddrList, consensusAddr)` | Claims all the reward and delegates them to the consensus address                  |

### Reward Calculation

- Read how the reward is calculated for delegator at [Staking Problem: Reward Calculation](https://skymavis.notion.site/Staking-Problem-Reward-Calculation-bd47bbcefde24bbd8e959bee45dfd4a5).
- See [`RewardCalculation` contract](./contracts/staking/RewardCalculation.sol) for the implementation.

## Validator Contract

The validator contract collects and distributes staking rewards, syncs the validator set from the staking contract at the end of every epoch.

![image](./assets/Validator%20Contract%20Overview.drawio.png)
_Validator contract flow overview_

1. The block producer trigger to the Validator contract to wrap up the epoch.
2. Validator contract counts the validator/delegator rewards to the Staking contract.
3. Validator contract syncs validator set from staking contract.

At the end of period, the validator contract:

4. Transfers the rewards for validators.
5. Resets the slashing counter.

## Slashing

The validators will be slashed when they do not provide the good service for Ronin network.

**Unavailability**

- If a validator missed >= `misdemeanorThreshold` blocks in a day: Cannot claim the reward on that day.

- If a validator missed >= `felonyThreshold` blocks in a day:
  - Cannot claim the reward on that day.
  - Be slashed `slashFelonyAmount` amount of self-delegated RON.
  - Be put in jail for `57600` blocks.

**Double Sign**

- If a validator submit more than 1 block at the same `block.number`:
  - Cannot claim the reward.
  - Be put in jail for `type(uint256).max` blocks.
  - Be slashed `slashDoubleSignAmount` amount of self-delegated RON.

## Contract Interaction flow

Read the contract interaction flow at [DPoS Contract: Interaction Flow](https://skymavis.notion.site/DPoS-Contract-Interaction-Flow-3a535cf9048f46f69dd9a45958ad9b85).

## Development

### Requirement

- Node@>=14 + Solc@^0.8.0

### Compile & test

```shell
$ yarn install
$ yarn compile
$ yarn test
```

## Deployment

- Init the environment variables:

```shell
$ cp .env.example .env && vim .env
```

- Update the contract configuration in [`config.ts`](./src/config.ts#L55-L96) file

- Deploy the contracts:

```shell
$ yarn hardhat deploy --network <ronin-devnet|ronin-mainnet|ronin-testnet>
```
