# Ronin DPoS Contracts

The collections of smart contracts that power the Ronin Delegated Proof of Stake (DPoS) network.

## Development

### Requirement

- Node@>=14 + Solc@^0.8.0

### Compile & test

- Add Github NPM token to install packages, and then replace `{YOUR_TOKEN}` in `.npmrc` file by any arbitrary Github token with `read:packages` permission.

  > **Note**: To create a new token, please refer to [this article](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token). The token must have `read:packages` permission.

  ```shell
  cp .npmrc.example .npmrc && vim .npmrc
  ```

- Install packages

  ```shell
  $ yarn --frozen-lockfile
  ```

- Install foundry libs

    ```
    $ git submodule add -b release-v0 https://github.com/PaulRBerg/prb-test lib/prb-test
    ```

- Compile contracts

  ```shell
  $ yarn compile
  ```

- Run test

  ```shell
  $ yarn test
  ```

- Extract storage layout
  ```shell
  $ yarn plugin:storage-layout [--destination <output-path>] [--override <true|false>]
  ```
  - `<output-path>` (optional): The path to store generated storage layout file. If not provided, the default path is `layout/storage.txt`.
  - `--override` (optional): Indicates whether to override the destination file at `<output-path>` if it already exists. By default, it is set to `false`.

### Target chain to deploy

This repo contains source code of contracts that will be either deployed on the mainchains, or on Ronin chain.

- On mainchains:
  - Governance contract: `MainchainGovernanceAdmin`
  - Bridge contract: `MainchainGatewayV2`
  - Trusted orgs contract: `RoninTrustedOrganization`
- On Ronin chain:
  - Governance contract: `RoninGovernanceAdmin`
  - Bridge operation: `RoninGatewayV2`
  - Trusted orgs contract: `RoninTrustedOrganization`
  - DPoS contracts

### Upgradeability & Governance mechanism

Except for the governance contracts and vault forwarder contracts, all other contracts are deployed following the proxy pattern for upgradeability. The [`TransparentUpgradeableProxyV2`](./contracts/extensions/TransparentUpgradeableProxyV2.sol), an extended version of [OpenZeppelin's](https://docs.openzeppelin.com/contracts/3.x/api/proxy#TransparentUpgradeableProxy), is used for deploying the proxies.

To comply with the [governance process](./docs/README.md#governance), in which requires all modifications to a contract must be approved by a set of governors, the admin role of all proxies must be granted for the governance contract address.

### Deployment steps

- Init the environment variables

  ```shell
  $ cp .env.example .env && vim .env
  ```

- Update the contract configuration in [`config.ts`](./src/config.ts) file

- Deploy the contracts

  ```shell
  $ yarn hardhat deploy --network <local|ronin-devnet|ronin-mainnet|ronin-testnet>
  ```

## Documentation

See [docs/README.md](./docs/README.md) for the documentation of the contracts.

See [docs/HACK.md](./docs/HACK.md) for the structure of the repo.

For the contract interaction flow, please refer to [DPoS Contract: Interaction Flow](https://skymavis.notion.site/DPoS-Contract-Interaction-Flow-3a535cf9048f46f69dd9a45958ad9b85).

For the whitepaper, please refer to [Ronin Whitepaper](https://www.notion.so/skymavis/Ronin-Whitepaper-deec289d6cec49d38dc6e904669331a5).
