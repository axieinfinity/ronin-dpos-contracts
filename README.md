# Ronin DPoS Contracts

The collections of smart contracts that power the Ronin Delegated Proof of Stake (DPoS) network.

## Development

### Requirement

- Node@>=14 + Solc@^0.8.0

### Compile & test

```shell
$ yarn --frozen-lockfile
$ yarn compile
$ yarn test
```

## Deployment

On main chains, we need to deploy the governance contract and bridge contracts: `RoninTrustedOrganization`, `MainchainGovernanceAdmin` and `MainchainGatewayV2`.

On Ronin we deploy `RoninGatewayV2` for bridge operation and the DPoS contracts.

All contracts (except the governance contracts and vault forwarder contracts) are upgradeable following the governance process. We use [`TransparentUpgradeableProxy`](https://docs.openzeppelin.com/contracts/3.x/api/proxy#TransparentUpgradeableProxy) for this use case, and they should grant the governance contract the role of admin.

Here is the deployment steps:

- Init the environment variables:

```shell
$ cp .env.example .env && vim .env
```

- Update the contract configuration in [`config.ts`](./src/config.ts) file

- Deploy the contracts:

```shell
$ yarn hardhat deploy --network <local|ronin-devnet|ronin-mainnet|ronin-testnet>
```

## Documentation

See [docs/README.md](./docs/README.md) for the documentation of the contracts.

See [docs/HACK.md](./docs/HACK.md) for the structure of the repo.

For the contract interaction flow, please refer to [DPoS Contract: Interaction Flow](https://skymavis.notion.site/DPoS-Contract-Interaction-Flow-3a535cf9048f46f69dd9a45958ad9b85).

For the whitepaper, please refer to [Ronin Whitepaper](https://www.notion.so/skymavis/Ronin-Whitepaper-deec289d6cec49d38dc6e904669331a5).
