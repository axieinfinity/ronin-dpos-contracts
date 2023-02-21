# Deployment cheatsheet

## Account dependency graph

## Gateway
### Ronin Gateway Proxy

- [ ] [`initialize`](https://github.com/axieinfinity/ronin-dpos-contracts/blob/5ef887dba49571c32b7e59e56d8ddde29d1a09c4/contracts/ronin/RoninGatewayV2.sol#L68-L80): this sets initializing data, without validator contract
- [ ] Deploy proxy: Should deploy with private-key based account as admin, for easily setting up the next step
- [ ] [`setValidatorContract`](https://github.com/axieinfinity/ronin-dpos-contracts/blob/5ef887dba49571c32b7e59e56d8ddde29d1a09c4/contracts/ronin/RoninGatewayV2.sol#L103)
- [ ] Transfer admin to GA (optional)