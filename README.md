# Invariant Testing Bootcamp

**Started:** 26 January 2026

## Exercises

1. Scaffold ERC4626 vault → reach **90% coverage**
   - [Solmate](https://github.com/transmissions11/solmate)
2. Add stateful + stateless properties (ERC-4626 specs)
3. Compare Echidna vs Foundry
4. Explore Create Chimera App
5. Find bugs!

## This repo (Week 1 / Exercise 1)

- **Cloned target**: `src/erc4626/SolmateERC4626.sol` (local copy of Solmate’s `ERC4626`)
- **Concrete vault for testing**: `src/mocks/MockERC4626.sol`
- **Coverage-first test folder**: `test/erc4626/`

## Commands

### Build

```bash
forge build
```

### Run tests

```bash
forge test -vvv
```

### Coverage (goal: >90%)

```bash
forge coverage -vvv
```
