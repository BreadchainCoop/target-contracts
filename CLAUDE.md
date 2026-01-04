# CLAUDE.md

Guidance for Claude Code when working with this repository. See [README.md](./README.md) for full documentation.

## Key Sections

- [Quick Start](./README.md#quick-start) - Build, test, format commands
- [Architecture](./README.md#architecture) - Two-chain design, contracts, state bridge flow
- [Development](./README.md#development) - Environment setup, testing, deployment
- [E2E Testing](./README.md#e2e-testing) - Docker-based integration tests
- [Implementation Details](./README.md#implementation-details) - Gas optimization, proof verification
- [Common Gotchas](./README.md#common-gotchas) - Known issues and limitations

## Quick Reference

**Two-chain architecture:**
- L1: `MiddlewareShim` snapshots EigenLayer operator state
- L2: `RegistryCoordinatorMimic` verifies state via SP1 Helios proofs

**Commands:**
```bash
cd contracts
forge build && forge test && forge fmt
```

**Critical implementation notes:**
- `updateState()` uses assembly for gas-efficient array length setting
- Most logic hardcoded for quorum 0; multi-quorum is TODO
- Uses EigenLayer M2 middleware (pre-AllocationManager)
- `DeployEnvironment.s.sol` has build errors (doesn't affect core contracts)
