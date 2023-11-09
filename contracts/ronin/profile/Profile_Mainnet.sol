// SPDX-License-Identifier: MIT

import "./Profile.sol";

pragma solidity ^0.8.9;

contract Profile_Mainnet is Profile {
  function __migrationRenouncedCandidates() internal override onlyInitializing {
    if (block.chainid != 2020) return;

    uint length;
    CandidateProfile storage _profile;

    address[4] memory lConsensus = __consensuses();
    address[4] memory lAdmin = __admins();
    address[4] memory lTreasury = __treasuries();

    for (uint i; i < length; ++i) {
      address id = lConsensus[i];

      _profile = _id2Profile[id];
      _profile.id = id;
      _setConsensus(_profile, TConsensus.wrap(id));
      _setAdmin(_profile, lAdmin[i]);
      _setTreasury(_profile, payable(lTreasury[i]));
    }
  }

  function __admins() private pure returns (address[4] memory list) {
    return [
      0xdb3b1F69259f88Ce9d58f3738e15e3CC1B5A8563,
      0x335fE9EF827a9F27CBAb819b31e5eE182c2081d7,
      0xbCcB3FDa2B9e3Ab5b824AA9D5c1C4A62A98Da937,
      0x9bc1946f1Aa6DA4667a6Ee966e66b9ec60637E10
    ];
  }

  function __consensuses() private pure returns (address[4] memory list) {
    return [
      0x07d28F88D677C4056EA6722aa35d92903b2a63da,
      0x262B9fcfe8CFA900aF4D1f5c20396E969B9655DD,
      0x20238eB5643d4D7b7Ab3C30f3bf7B8E2B85cA1e7,
      0x03A7B98C226225e330d11D1B9177891391Fa4f80
    ];
  }

  function __treasuries() private pure returns (address[4] memory list) {
    return [
      0xdb3b1F69259f88Ce9d58f3738e15e3CC1B5A8563,
      0x335fE9EF827a9F27CBAb819b31e5eE182c2081d7,
      0xbCcB3FDa2B9e3Ab5b824AA9D5c1C4A62A98Da937,
      0x9bc1946f1Aa6DA4667a6Ee966e66b9ec60637E10
    ];
  }
}
