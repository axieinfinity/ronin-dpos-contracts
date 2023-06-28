import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import 'hardhat-contract-sizer';
import '@solidstate/hardhat-4byte-uploader';
import 'hardhat-storage-layout';
import '@nomicfoundation/hardhat-foundry';

import * as dotenv from 'dotenv';
import { HardhatUserConfig, NetworkUserConfig, SolcUserConfig } from 'hardhat/types';
import './src/tasks/generate-storage-layout';
dotenv.config();

const DEFAULT_MNEMONIC = 'title spike pink garlic hamster sorry few damage silver mushroom clever window';

const { REPORT_GAS, FORKING_URL } = process.env;

if (!FORKING_URL) {
  console.error('FORKING_URL is unset.');
}

const compilerConfig: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    /// @dev see: https://github.com/Uniswap/v3-core/blob/main/hardhat.config.ts
    metadata: {
      // do not include the metadata hash, since this is machine dependent
      // and we want all generated code to be deterministic
      // https://docs.soliditylang.org/en/v0.8.17/metadata.html
      bytecodeHash: 'none',
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
        },
      },
    },
  },
  typechain: {
    outDir: 'src/types',
  },
  paths: {
    deploy: ['src/deploy', 'src/upgrades'],
  },
  namedAccounts: {
    deployer: 0,
    // governor: '0x00000000000000000000000000000000deadbeef',
    // governor: 'trezor://0x0000000000000000000000000000000000000000',
  },
  networks: {
    'ronin-testnet': {
      hardfork: 'istanbul',
      accounts: {
        mnemonic: DEFAULT_MNEMONIC,
        count: 150,
        accountsBalance: '1000000000000000000000000000', // 1B RON
      },
      forking: {
        url: FORKING_URL || '',
      },
      url: FORKING_URL,
      allowUnlimitedContractSize: true,
    },
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
