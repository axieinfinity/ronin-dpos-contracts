// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import { BaseScript, ContractKey } from "./BaseScript.s.sol";
// import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
// import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
// import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
// import { ContractType } from "@ronin/contracts/utils/ContractType.sol";

// contract Propose is Propose {
//   using GlobalProposal for *;

//   function run() public virtual {
//     GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[1];
//     targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;

//     uint256[] memory values = new uint256[](1);
//     uint256[] memory gasAmounts = new uint256[](1);
//     bytes[] memory callDatas = new bytes[](1);

//     gasAmounts[0] = 500_000;
//     callDatas[0] = abi.encodeCall(
//       RoninGatewayV2.setContract,
//       ContractType.BridgeTracking,
//       _config.getAddressFromCurrentNetwork(ContractKey.BridgeTracking)
//     );

//     RoninBridgeManager roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(ContractKey.RoninBridgeManager));

//     bytes32 digest = ECDSA.toTypedDataHash(roninBridgeManager, roninBridgeManager.)
//   }
// }
