# Target Contracts

EigenLayer middleware state bridge to L2 using SP1Helios. Deploys a `MiddlewareShim` on L1 to snapshot operator state and a `RegistryCoordinatorMimic` on L2 to verify and store it.

## Quick Start

```bash
# Build
cd contracts
forge build

# Test
forge test

# Format
forge fmt
```

## Structure

```
contracts/
  src/
    MiddlewareShim.sol           # L1: Snapshots EigenLayer operator state
    RegistryCoordinatorMimic.sol # L2: Verifies state via SP1 Helios proofs
  test/                          # Unit and fork tests
  script/                        # Deployment scripts

e2e/                             # Docker-based integration tests
```

## Environment

Copy `contracts/.env.example` to `contracts/.env` and set:
- `PRIVATE_KEY`
- `RPC_URL`
- `REGISTRY_COORDINATOR`

## E2E Testing

```bash
cd e2e/docker
./deploy-bls-testnet.sh
```

See [CLAUDE.md](./CLAUDE.md) for architecture details and development guide
