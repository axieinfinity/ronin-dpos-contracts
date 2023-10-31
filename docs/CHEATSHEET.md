# Deployment cheatsheet

## Account dependency graph

## Gateway
### Ronin Gateway Proxy

1. Setup & Deploy

- [ ] [`initialize`](https://github.com/axieinfinity/ronin-dpos-contracts/blob/5ef887dba49571c32b7e59e56d8ddde29d1a09c4/contracts/ronin/RoninGatewayV3.sol#L68-L80): this sets initializing data, without validator contract
- [ ] Deploy proxy: Should deploy with private-key based account as admin, for easily setting up the next step
- [ ] [`setValidatorContract`](https://github.com/axieinfinity/ronin-dpos-contracts/blob/5ef887dba49571c32b7e59e56d8ddde29d1a09c4/contracts/ronin/RoninGatewayV3.sol#L103)
- [ ] [`setBridgeTrackingContract`](https://github.com/axieinfinity/ronin-dpos-contracts/blob/95d7e94dea2d33e1835c51aa104114c18ff8df4c/contracts/ronin/RoninGatewayV3.sol#L118)
- [ ] Transfer admin to GA (optional)

2. Grant role of minter or top-up initial value for gateway