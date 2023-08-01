# Spec

## CircuitBreaker

- [x] Is owned (ERC137)

- [x] Pausing protocol through `onlyOperational` and `isOperational`

- [x] Supports native and ERC20 assets

  - [x] Native/Token inflow/outflow functions

- [x] Supports multiple "protected" contracts

  - [x] add contracts
  - [x] remove contracts

- [x] Rate limit is per asset

- [x] In case of withdrawal triggering, either:
  - [x] Revert
  - [x] Transfer funds to Timelock

## DSM (Timelock)

- [ ]

## Rate Limiter

- [ ] TODO: Include Cooldown here
- [ ] TODO: return status on change
- [ ]

- [ ] Review
- [ ] Minimize
