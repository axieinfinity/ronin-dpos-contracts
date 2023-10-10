import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import 'hardhat-contract-sizer';
import '@solidstate/hardhat-4byte-uploader';
import 'hardhat-storage-layout';

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig, SolcUserConfig } from 'hardhat/types';
import './src/tasks/generate-storage-layout';
dotenv.config();

const DEFAULT_MNEMONIC = 'title spike pink garlic hamster sorry few damage silver mushroom clever window';

const {
  REPORT_GAS,
  DEVNET_PK,
  DEVNET_URL,
  TESTNET_PK,
  TESTNET_URL,
  MAINNET_PK,
  MAINNET_URL,
  GOERLI_URL,
  GOERLI_PK,
  ETHEREUM_URL,
  ETHEREUM_PK,
} = process.env;

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

if (!ETHEREUM_PK) {
  console.warn('ETHEREUM_PK is unset. Using DEFAULT_MNEMONIC');
}

const local: NetworkUserConfig = {
  url: 'http://localhost:8545',
  accounts: { mnemonic: DEFAULT_MNEMONIC },
};

const devnet: NetworkUserConfig = {
  url: DEVNET_URL || 'http://localhost:8545',
  accounts: DEVNET_PK ? [DEVNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  companionNetworks: {
    mainchain: 'goerli-for-devnet',
  },
};

const testnet: NetworkUserConfig = {
  chainId: 2021,
  url: TESTNET_URL || 'https://saigon-testnet.roninchain.com/rpc',
  accounts: TESTNET_PK ? [TESTNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
  companionNetworks: {
    mainchain: 'goerli',
  },
};

const mainnet: NetworkUserConfig = {
  chainId: 2020,
  url: MAINNET_URL || 'https://api.roninchain.com/rpc',
  accounts: MAINNET_PK ? [MAINNET_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
  companionNetworks: {
    mainchain: 'ethereum',
  },
};

const goerli: NetworkUserConfig = {
  chainId: 5,
  url: GOERLI_URL || 'https://gateway.tenderly.co/public/goerli',
  accounts: GOERLI_PK ? [GOERLI_PK] : { mnemonic: DEFAULT_MNEMONIC },
  blockGasLimit: 100000000,
};

const ethereum: NetworkUserConfig = {
  chainId: 1,
  url: ETHEREUM_URL || 'https://gateway.tenderly.co/public/mainnet',
  accounts: ETHEREUM_PK ? [ETHEREUM_PK] : { mnemonic: DEFAULT_MNEMONIC },
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
    compilers: [compilerConfig],
    overrides: {
      'contracts/ronin/validator/RoninValidatorSet.sol': {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
          /// @dev see: https://github.com/Uniswap/v3-core/blob/main/hardhat.config.ts
          metadata: {
            // do not include the metadata hash, since this is machine dependent
            // and we want all generated code to be deterministic
            // https://docs.soliditylang.org/en/v0.8.17/metadata.html
            bytecodeHash: 'none',
          },
        },
      },
      'contracts/ronin/gateway/RoninBridgeManager.sol': {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
          /// @dev see: https://github.com/Uniswap/v3-core/blob/main/hardhat.config.ts
          metadata: {
            // do not include the metadata hash, since this is machine dependent
            // and we want all generated code to be deterministic
            // https://docs.soliditylang.org/en/v0.8.17/metadata.html
            bytecodeHash: 'none',
          },
        },
      },
    },
  },
  typechain: {
    outDir: 'src/types',
  },
  paths: {
    deploy: ['src/deploy', 'src/upgrades'],
    tests: 'test/hardhat_test',
  },
  namedAccounts: {
    deployer: 0,
    governor: 0,
    // governor: '0x00000000000000000000000000000000deadbeef',
    // governor: 'trezor://0x0000000000000000000000000000000000000000',
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
    'goerli-for-devnet': goerli,
    ethereum,
  },
  gasReporter: {
    enabled: REPORT_GAS ? true : false,
    showTimeSpent: true,
  },
  // etherscan: {
  //   apiKey: process.env.ETHERSCAN_API_KEY,
  // },
  mocha: {
    timeout: 100000, // 100s
  },

  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    outputFile: './logs/contract_code_sizes.log',
  },
};

export default config;
