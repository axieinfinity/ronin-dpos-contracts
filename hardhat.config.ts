import '@typechain/hardhat';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import 'hardhat-contract-sizer';
import '@axieinfinity/hardhat-4byte-uploader';

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig, SolcUserConfig } from 'hardhat/types';

dotenv.config();

const DEFAULT_MNEMONIC = 'title spike pink garlic hamster sorry few damage silver mushroom clever window';

const { REPORT_GAS, DEVNET_PK, DEVNET_URL, TESTNET_PK, TESTNET_URL, MAINNET_PK, MAINNET_URL, GOERLI_URL, GOERLI_PK } =
  process.env;

if (!DEVNET_PK) {
  console.warn('DEVNET_PK is unset. Using DEFAULT_MNEMONIC');
}

if (!TESTNET_PK) {
  console.warn('TESTNET_PK is unset. Using DEFAULT_MNEMONIC');
}

if (!MAINNET_PK) {
  console.warn('MAINNET_PK is unset. Using DEFAULT_MNEMONIC');
}

if (!GOERLI_PK) {
  console.warn('GOERLI_PK is unset. Using DEFAULT_MNEMONIC');
}

const local: NetworkUserConfig = {
  url: 'http://localhost:8545',
  accounts: { mnemonic: DEFAULT_MNEMONIC },
};

const devnet: NetworkUserConfig = {
  url: DEVNET_URL || 'http://localhost:8545',
  accounts: DEVNET_PK ? [DEVNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
};

const testnet: NetworkUserConfig = {
  chainId: 2021,
  url: TESTNET_URL || 'https://testnet.skymavis.one/rpc',
  accounts: TESTNET_PK ? [TESTNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const mainnet: NetworkUserConfig = {
  chainId: 2020,
  url: MAINNET_URL || 'https://api.roninchain.com/rpc',
  accounts: MAINNET_PK ? [MAINNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const goerli: NetworkUserConfig = {
  chainId: 5,
  url: GOERLI_URL || '',
  accounts: GOERLI_PK ? [GOERLI_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const compilerConfig: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [compilerConfig, { ...compilerConfig, version: '0.5.17' }],
  },
  typechain: {
    outDir: 'src/types',
  },
  paths: {
    deploy: 'src/deploy',
  },
  namedAccounts: {
    deployer: 0,
    // trezor: 'trezor://0x0000000000000000000000000000000000000000',
  },
  networks: {
    hardhat: {
      hardfork: 'istanbul',
      accounts: {
        mnemonic: DEFAULT_MNEMONIC,
        count: 150,
        accountsBalance: '1000000000000000000000000000', // 1B RON
      },
      allowUnlimitedContractSize: true,
    },
    local,
    'ronin-devnet': devnet,
    'ronin-testnet': testnet,
    'ronin-mainnet': mainnet,
    goerli,
  },
  gasReporter: {
    enabled: REPORT_GAS ? true : false,
    showTimeSpent: true,
  },
  mocha: {
    timeout: 100000, // 100s
  },
};

export default config;
