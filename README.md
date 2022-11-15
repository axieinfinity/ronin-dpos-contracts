# Ronin DPoS Contracts

The collections of smart contracts that power the Ronin Delegated Proof of Stake (DPoS) network.

Read more details at the [Ronin Whitepaper](https://www.notion.so/skymavis/Ronin-Whitepaper-deec289d6cec49d38dc6e904669331a5).

- [Overview](#ronin-dpos-contracts)
  - [Governance](#governance)
    - [Ronin Trusted Organization](#ronin-trusted-organization)
    - [Bridge Operators Ballot](#bridge-operators-ballot)
    - [Proposals](#proposals)
  - [Staking](#staking)
    - [Validator Candidate](#validator-candidate)
    - [Delegator](#delegator)
    - [Reward Calculation](#reward-calculation)
  - [Validator Contract & Rewarding](#validator-contract--rewarding)
    - [Block reward submission](#block-reward-submission)
    - [Wrapping up epoch](#wrapping-up-epoch)
  - [Slashing](#slashing)
    - [Unavailability](#unavailability)
    - [Double Sign](#double-sign)
    - [](#)
  - [Contract Interaction flow](#contract-interaction-flow)
- [Development](#development)
  - [Requirement](#requirement)
  - [Compile & test](#compile--test)
- [Deployment](#deployment)

---

0. Ronin Trusted Orgs
1. Staking
2. Validator
3. Slashing
4. Maintenance

---

5. Staking Vesting
   Bridges

---

6. Bridge
   BridgeTracking

---

## Governance

We have a group of trusted organizations that are chosen by the community and Sky Mavis. Their tasks are to take part in the Validator set and govern the network configuration through the on-chain governance process:

- Update the system parameters, e.g: slash thresholds, and add/remove trusted organizations,...
- Sync the set of bridge operators to the Ethereum chain every period.

![image](./assets/Bridge%20Governance.png)

_Governance flow overview_

The governance contracts (`RoninGovernanceAdmin` and `MainchainGovernanceAdmin`) are mainly responsible for the governance process via a decentralized voting mechanism. At any instance, there will be maximum one governance vote going on per network.

### Ronin Trusted Organization

| Properties              | Explanation                                                                        |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `address consensusAddr` | Address of the validator that produces block. This is so-called validator address. |
| `address governor`      | Address to voting proposal                                                         |
| `address bridgeVoter`   | Address to voting bridge operators                                                 |
| `uint256 weight`        | Governor weight                                                                    |

### Bridge Operators Ballot

```js
// keccak256("BridgeOperatorsBallot(uint256 period,address[] operators)");
const TYPEHASH = 0xeea5e3908ac28cbdbbce8853e49444c558a0a03597e98ef19e6ff86162ed9ae3;
```

| Name        | Type        | Explanation                                      |
| ----------- | ----------- | ------------------------------------------------ |
| `period`    | `uint256`   | The period that these operators are active       |
| `operators` | `address[]` | List of address that the BridgeAdmin has to call |

### Proposals

**Per-chain Proposal**

```js
// keccak256("ProposalDetail(uint256 nonce,uint256 chainId,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
const TYPE_HASH = 0x65526afa953b4e935ecd640e6905741252eedae157e79c37331ee8103c70019d;
```

| Name         | Type        | Explanation                                                   |
| ------------ | ----------- | ------------------------------------------------------------- |
| `nonce`      | `uint256`   | The proposal nonce                                            |
| `chainId`    | `uint256`   | The chain id to execute the proposal (id = 0 for all network) |
| `targets`    | `address[]` | List of address that the BridgeAdmin has to call              |
| `values`     | `uint256[]` | msg.value to send for targets                                 |
| `calldatas`  | `bytes[]`   | Data to call to the targets                                   |
| `gasAmounts` | `uint256[]` | Gas amount to call                                            |

**Global Proposal**

The governance has 2 target options to call to globally:

- Option 0: `RoninTrustedOrganization` contract
- Option 1: `Bridge` contract

```js
// keccak256("GlobalProposalDetail(uint256 nonce,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
const TYPE_HASH = 0xdb316eb400de2ddff92ab4255c0cd3cba634cd5236b93386ed9328b7d822d1c7;
```

| Name            | Type        | Explanation                   |
| --------------- | ----------- | ----------------------------- |
| `nonce`         | `uint256`   | The proposal nonce            |
| `targetOptions` | `uint8[]`   | List of options               |
| `values`        | `uint256[]` | msg.value to send for targets |
| `calldatas`     | `bytes[]`   | Data to call to the targets   |
| `gasAmounts`    | `uint256[]` | Gas amount to call            |

## Staking

The users can propose themselves to be validator candidates by staking their RON. Other users are allowed to register as delegators by staking any amount of RON to the staking contract, (s)he can choose a candidate to stake their coins.

### Validator Candidate

**Applying to be validator candidate**

| Params                       | Explanation                                                                                                                                         |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `address candidateAdmin`     | The candidate admin will be stored in the validator contract, used for calling function that affects to its candidate, e.g. scheduling maintenance. |
| `address consensusAddr`      | Address to produce block                                                                                                                            |
| `address treasuryAddr`       | Address to receive block reward                                                                                                                     |
| `address bridgeOperatorAddr` | Address of the bridge operator                                                                                                                      |
| `uint256 commissionRate`     | The rate to share for the validator. Values in range [0; 100_00] stands for [0; 100%]                                                               |
| `msg.value`                  | The amount of RON to stake, require to be larger than or equal to the threshold `minValidatorStakingAmount()` to be validator                       |

The validator candidates can deposit or withdraw their funds afterwards as long as the staking balance must be greater than the threshold `minValidatorStakingAmount()`.

**Renouncing validator**

The candidates can renounce and take back their deposited RON at the next period ending after waiting `waitingSecsToRevoke()` seconds.

### Delegator

The delegator can choose the validator to stake and receive the commission reward:

| Methods                                                  | Explanation                                                                        |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `delegate(consensusAddr)`                                | Stakes `msg.value` amount of RON for a validator `consensusAddr`                   |
| `undelegate(consensusAddr, amount)`                      | Unstakes from a validator                                                          |
| `redelegate(consensusAddrSrc, consensusAddrDst, amount)` | Unstakes `amount` RON from the `consensusAddrSrc` and stake for `consensusAddrDst` |
| `getRewards(consensusAddrList)`                          | Returns all of the claimable rewards                                               |
| `claimRewards(consensusAddrList)`                        | Claims all the reward from the validators                                          |
| `delegateRewards(consensusAddrList, consensusAddr)`      | Claims all the reward and delegates them to the consensus address                  |

The delegator has to wait at least `cooldownSecsToUndelegate()` seconds from the last timestamp (s)he delegated before undelegating.

### Reward Calculation

The reward is calculated based on the minimum staking amount in the current period of a specific delegator.

For example:

| Period      | Action            | Reward                  | Explanation                                                                                       |
| ----------- | ----------------- | ----------------------- | ------------------------------------------------------------------------------------------------- |
| -           | UserA: +500       |                         | Staking action before the hardfork block does affect the reward calculation at the first period x |
|             | UserA: -450       |                         |                                                                                                   |
|             | UserA: +50        |                         | StakingAmount(UserA)= 500 → 50 → 100                                                              |
|             | UserB: +100       |                         | StakingAmount(UserB)= 0 → 100                                                                     |
| x           | -                 | -                       | Hardfork block                                                                                    |
|             | UserA: -60        |                         | StakingAmount(UserA)=100 → 40                                                                     |
|             | UserB: -90        |                         | StakingAmount(UserB)=100 → 10                                                                     |
|             | UserB: +40        |                         | StakingAmount(UserB)=10 → 50                                                                      |
| Wrap up x   | Pool reward: 2000 | UserA+=1600; UserB+=400 | Minimum balance of UserA is 40 (80%); Minimum balance of UserB is 10 (20%)                        |
| x+1         | UserA: +10        | -                       | StakingAmount(UserA)=40 → 50                                                                      |
|             | UserB: -10        | -                       | StakingAmount(UserB)=50 → 40                                                                      |
| Wrap up x+1 | Pool reward: 2000 | UserA+=1000 UserB+=1000 | Minimum balance of UserA is 40 (50%) Minimum balance of UserB is 40 (50%)                         |

- Read how the reward is calculated for delegator at [Staking Problem: Reward Calculation](https://skymavis.notion.site/Staking-Problem-Reward-Calculation-bd47bbcefde24bbd8e959bee45dfd4a5).

- See [`RewardCalculation` contract](./contracts/ronin/staking/RewardCalculation.sol) for the implementation.

## Validator Contract & Rewarding

The top users with the highest amount of staked coins will be considered to be validators after prioritizing the trusted organizations. The total number of validators do not larger than `maxValidatorNumber()`. Each validator will be a block producer and a bridge relayer, whenever a validator gets jailed its corresponding block producer will not be able to receive the block reward.

### Block reward submission

The block producers submit their block reward at the end of each block, and the amount of reward will be transferred to the block miner and its corresponding delegators at the end of the period (~1 day).

### Wrapping up epoch

![image](./assets/Validator%20Contract%20Overview.drawio.png)
_Validator contract flow overview_

1. The block producer calls the contract `RoninValidatorSet.wrapUpEpoch()` to filter jailed/maintaining block producers.

At the end of each period, the contract:

2. Distributes mining reward and bridge relaying reward for the current validators.
3. Updates credit scores in the contract `SlashIndicator`.
4. Syncs the new validator set by using to precompiled contract.

## Slashing

The validators will be slashed when they do not provide good service for Ronin network.

### Unavailability

| Properties                                    | Explanation                                                                                                                                    |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `unavailabilityTier1Threshold`                | The mining reward will be deprecated, if (s)he missed more than this threshold.                                                                |
| `unavailabilityTier2Threshold`                | The mining reward will be deprecated, (s)he will be put in jailed, and will be deducted self-staking if (s)he misses more than this threshold. |
| `slashAmountForUnavailabilityTier2Threshold`  | The amount of RON to deduct from self-staking of a block producer when (s)he is slashed tier-2.                                                |
| `jailDurationForUnavailabilityTier2Threshold` | The number of blocks to jail a block producer when (s)he is slashed tier-2.                                                                    |

### Double Sign

| Properties                    | Explanation                                                                               |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| `slashDoubleSignAmount`       | The amount of RON to slash double sign.                                                   |
| `doubleSigningJailUntilBlock` | The block number that the punished validator will be jailed until, due to double signing. |

###

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

- Update the contract configuration in [`config.ts`](./src/config.ts) file

- Deploy the contracts:

```shell
$ yarn hardhat deploy --network <local|ronin-devnet|ronin-mainnet|ronin-testnet>
```
