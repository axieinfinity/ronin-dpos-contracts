# Code structure of the Ronin DPoS contracts repo

The structure of the repo is as follows.

```
├── contracts
│   ├── extensions              <-- helpers and shared contracts
│   ├── interfaces              <-- interfaces
│   ├── libraries               <-- libraries
│   ├── mainchain               <-- contracts should only deployed on mainchain (gateway and governance)
│   ├── mocks                   <-- mock contracts used in tests
│   ├── multi-chains            <-- Ronin trusted orgs contracts
│   ├── precompile-usages       <-- wrapper for precompiled calls
│   └── ronin                       <-- contracts should only deployed on testnet
│       ├── slash-indicator             <-- slashing and credit score contracts
│       ├── staking                     <-- pool and staking contracts
│       ├── validator                   <-- validator set contracts
|       └── ...                         <-- other single file contracts
├── docs                        <-- documentation
├── src                         <-- deployment scripts
│   ├── deploy                      <-- hardhat-deploy scripts
│   └── script                      <-- helpers for deploy scripts
└── test                        <-- tests
```