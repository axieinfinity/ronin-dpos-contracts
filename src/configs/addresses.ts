import { Network } from '../utils';
import { TrustedOrganizationStruct } from '../types/IRoninTrustedOrganization';

export type LiteralNetwork = Network | string;

interface AccountSet {
  [name: string]: { [network in LiteralNetwork]: undefined | string[] };
}

export const gatewayAccountSet: AccountSet = {
  relayers: {
    [Network.Hardhat]: undefined,
    [Network.Devnet]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
    [Network.GoerliForDevnet]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
    [Network.Goerli]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
  },
  withdrawalUnlockers: {
    [Network.Hardhat]: undefined,
    [Network.GoerliForDevnet]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
    [Network.Goerli]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
  },
  withdrawalMigrators: {
    [Network.Hardhat]: undefined,
    [Network.Devnet]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
    [Network.Goerli]: ['0x968D0Cd7343f711216817E617d3f92a23dC91c07'],
  },
};

interface TrustedOrganizationSet {
  [network: LiteralNetwork]: undefined | TrustedOrganizationStruct[];
}

const trustedOrgGoerliForDevnetConfig: TrustedOrganizationStruct[] = [
  {
    consensusAddr: '0xB6bc5bc0410773A3F86B1537ce7495C52e38f88B',
    governor: '0x6e61779A5aFf6F3400480981100d8f297Be98dB7',
    bridgeVoter: '0xB2106e0b921c682d824bd5276902a3DF822654DC',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x4a4bc674A97737376cFE990aE2fE0d2B6E738393',
    governor: '0x41c80F826fD726cc35C991ADabbf9C9765D4EE58',
    bridgeVoter: '0xEB6C9373bdD55348d6ef7C456a824705C6140222',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x3B9F2587d55E96276B09b258ac909D809961F6C2',
    governor: '0x6A55f2E6F3DdF2e2FC31f914d3d510f994E3E9E9',
    bridgeVoter: '0x95436f7544E1AbF9C9113fF9e5B37Eb6C9FFD075',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x283b4Baa1d0415603C81edc1C68FadD3C790837C',
    governor: '0x79F9D12Bf1C43556cA638c93De8299be18F4c13C',
    bridgeVoter: '0xCA8CD8490cfD91eecC1C9CA6a78c2EC7bd0b586B',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x0E3341Ae4Ed9dA65Fc30a7Fa6357e8B5Ac40b0A3',
    governor: '0x8a8B59B6a015faCF15aDe0e2Ac759EF1e4339f18',
    bridgeVoter: '0xb4e483A1A4B2a8214CA130A7AC4c0e5E82eAe6ee',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0xAfB9554299491a34d303f2C5A91bebB162f6B2Cf',
    governor: '0xa835C99C3EBE69Ea2940c3D009D541e452D47FE3',
    bridgeVoter: '0x324eD3822d6eC798824268De0895623165A4c3bc',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x912fb48E1C220699cC1Ee0bF5C00172c1C4d7733',
    governor: '0x60c44Bfb13B10Bb0897f8537bB987927a198842a',
    bridgeVoter: '0x107aA9956A8E2979C5DcaD3599AC9dF090E53D36',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x4F7B04Cceb6aDbeBFb0b64d2acb6FEBe2393F914',
    governor: '0x5ea8CC101AA90668594f473ef175d061225d62aa',
    bridgeVoter: '0xa19877E2c0cbb5C5eb7f37c417CAF1Fe14223840',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0xC2dbED259700DDE15eE95f797345a65ACABa511f',
    governor: '0x9484Cb3FC30ACa08732d423108A1212380d6CAd8',
    bridgeVoter: '0x16b655d62b4213ce9cb51b29A923b22B2EBb4375',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x4F7B05263cd535a561ab72059B4390cbC80f133D',
    governor: '0x10C9a7F733Fd74c5403190fD43529B651Ea53A74',
    bridgeVoter: '0x3F43595F669E77B67D11D02aa3498da6751C479B',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x23c148098A80fC3A47A87Fd7989C4b2D032dC906',
    governor: '0x755955288cFDd1143d3BBDE3C868972608376B9c',
    bridgeVoter: '0xAF83FdF1Cb2995f0767B2cc3480faaf970B1Bbd2',
    weight: 100,
    addedBlock: 0,
  },
];

const testnetTrustedOrgConfig: TrustedOrganizationStruct[] = [
  {
    consensusAddr: '0xAcf8Bf98D1632e602d0B1761771049aF21dd6597',
    bridgeVoter: '0x2295EdAA6BD5c07fB3227628c62Af12248106667',
    governor: '0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0xCaba9D9424D6bAD99CE352A943F59279B533417a',
    bridgeVoter: '0xb9e7cb842e24E92F49BF6dbAA1f2184C742cEb64',
    governor: '0xb033ba62EC622dC54D0ABFE0254e79692147CA26',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc',
    bridgeVoter: '0x7D1dA6CE4f3B908b8440889e6CeAcfD61839E8aC',
    governor: '0x087D08e3ba42e64E3948962dd1371F906D1278b9',
    weight: 100,
    addedBlock: 0,
  },
  {
    consensusAddr: '0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa',
    bridgeVoter: '0xcE6958090E8C57BB91A03dFc85D724Fb3903eEbf',
    governor: '0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F',
    weight: 100,
    addedBlock: 0,
  },
];

const mainnetTrustedOrgConfig: TrustedOrganizationStruct[] = [
  {
    consensusAddr: '0xf41af21f0a800dc4d86efb14ad46cfb9884fdf38',
    governor: '0xe880802580a1fbdef67ace39d1b21c5b2c74f059',
    bridgeVoter: '0x7bb3127bdb8eb364c3cc827331252e53af119993',
    weight: 100,
    addedBlock: 0,
  },
];

export const trustedOrgSet: TrustedOrganizationSet = {
  [Network.Hardhat]: undefined,

  [Network.GoerliForDevnet]: trustedOrgGoerliForDevnetConfig,
  [Network.Devnet]: trustedOrgGoerliForDevnetConfig,

  [Network.Testnet]: testnetTrustedOrgConfig,
  [Network.Goerli]: testnetTrustedOrgConfig,

  [Network.Mainnet]: mainnetTrustedOrgConfig,
  [Network.Ethereum]: mainnetTrustedOrgConfig,
};

interface ContractAddress {
  [name: string]: { [network in LiteralNetwork]: undefined | string };
}

export const namedAddresses: ContractAddress = {
  weth: {
    [Network.Hardhat]: undefined,
    [Network.Devnet]: '0x29C6F8349A028E1bdfC68BFa08BDee7bC5D47E16',
    [Network.GoerliForDevnet]: '0xfe63586e65ECcAF7A41b1B6D05384a9CA1B246a8',
    [Network.Goerli]: '0xfe63586e65ECcAF7A41b1B6D05384a9CA1B246a8',
  },
  gatewayRoleSetter: {
    [Network.Hardhat]: undefined,
    [Network.Devnet]: '0x968D0Cd7343f711216817E617d3f92a23dC91c07',
    [Network.GoerliForDevnet]: '0x968D0Cd7343f711216817E617d3f92a23dC91c07',
    [Network.Goerli]: '0x968D0Cd7343f711216817E617d3f92a23dC91c07',
  },
};
