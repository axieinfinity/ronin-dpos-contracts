// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

bytes constant EMPTY_PARAM = "";
uint256 constant ZERO_VALUE = 0;
string constant GOERLI_RPC = "https://eth-goerli.public.blastapi.io";
string constant RONIN_TEST_RPC = "https://saigon-archive.roninchain.com/rpc";

bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

// Saigon Testnet
TransparentUpgradeableProxyV2 constant RONIN_VALIDATOR_SET_CONTRACT = TransparentUpgradeableProxyV2(
  payable(0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d)
);
TransparentUpgradeableProxyV2 constant RONIN_BRIDGE_TRACKING_CONTRACT = TransparentUpgradeableProxyV2(
  payable(0x874ad3ACb2801733c3fbE31a555d430Ce3A138Ed)
);
RoninGovernanceAdmin constant RONIN_GOVERNANCE_ADMIN_CONTRACT = RoninGovernanceAdmin(
  payable(0x53Ea388CB72081A3a397114a43741e7987815896)
);
TransparentUpgradeableProxyV2 constant RONIN_GATEWAY_CONTRACT = TransparentUpgradeableProxyV2(
  payable(0xCee681C9108c42C710c6A8A949307D5F13C9F3ca)
);

// Goerli
TransparentUpgradeableProxyV2 constant ETH_GATEWAY_CONTRACT = TransparentUpgradeableProxyV2(
  payable(0xFc4319Ae9e6134C708b88D5Ad5Da1A4a83372502)
);
