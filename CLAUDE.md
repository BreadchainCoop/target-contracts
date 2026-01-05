# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains the Target Contracts for bridging EigenLayer middleware state to L2 chains using ZK proofs. It implements a "mimic" contract pattern that replicates EigenLayer's registry coordinator functionality on L2 by verifying state proofs from L1.

### Core Architecture

**Two-Chain Design:**
- **L1 (Ethereum/Sepolia)**: Hosts the `MiddlewareShim` contract that snapshots EigenLayer operator state
- **L2**: Hosts the `RegistryCoordinatorMimic` that verifies and stores this state using SP1 Helios light client proofs

**Key Contracts:**

1. **MiddlewareShim** (`contracts/src/MiddlewareShim.sol`)
   - Deployed on L1, reads from EigenLayer's `RegistryCoordinator`
   - Snapshots operator state (keys, stakes, quorums) at specific block numbers
   - Stores a `middlewareDataHash` representing the complete operator state
   - Aggregates data from BLSApkRegistry, StakeRegistry, and IndexRegistry

2. **RegistryCoordinatorMimic** (`contracts/src/RegistryCoordinatorMimic.sol`)
   - Deployed on L2, mimics the IRegistryCoordinator interface
   - Accepts `updateState()` calls with middleware data and Merkle proofs
   - Verifies storage proofs via SP1Helios light client
   - Stores operator state locally for BLS signature verification
   - **Important**: Uses direct assembly to set storage array lengths for gas efficiency

**State Bridge Flow:**
```
L1 MiddlewareShim.updateMiddlewareDataHash()
  → Snapshots operator state at block N
  → Stores keccak256(middlewareData) on L1

Generate proof off-chain
  → Merkle proof of L1 storage slot

L2 RegistryCoordinatorMimic.updateState(middlewareData, proof)
  → Verifies proof against SP1Helios light client
  → Updates local operator state
```

### Dependency Structure

The project uses Foundry with several key dependencies:

- **eigenlayer-middleware**: Core AVS middleware interfaces and libraries
- **sp1-helios**: SP1-based Ethereum light client for L1 state verification
- **openzeppelin-contracts**: Standard utilities
- **optimism**: RLP encoding and Merkle trie verification libraries
- **forge-std**: Testing framework

**Import Remappings** (see `contracts/foundry.toml`):
```
@eigenlayer-middleware/  → lib/eigenlayer-middleware/src/
@sp1-helios/            → lib/sp1-helios/contracts/src/
@sp1-contracts/         → lib/sp1-helios/contracts/lib/sp1-contracts/contracts/src/
@optimism/              → lib/optimism/packages/contracts-bedrock/src/
@openzeppelin-utils/    → lib/openzeppelin-contracts/contracts/utils/
```

## Development Commands

All commands should be run from the repository root unless otherwise specified.

### Building

```bash
# Build contracts (run from /contracts or repo root)
forge build

# Note: There is currently a compilation error in DeployEnvironment.s.sol
# that references an undefined constant. This doesn't affect the core contracts.
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path contracts/test/MiddlewareShim.t.sol

# Run specific test function
forge test --match-test test_getOperatorKeys

# Run with verbosity for debugging
forge test -vvv

# Run fork tests (requires RPC URL in .env)
forge test --match-contract OpacityForkTest --fork-url $RPC_URL
```

**Test Files:**
- `MiddlewareShim.t.sol`: Unit tests for state aggregation logic
- `RegistryCoordinatorMimic.t.sol`: Tests for state verification and storage
- `OpacityForkTest.t.sol`: Fork tests against live EigenLayer deployments
- `SimpleMPTVerification.t.sol`: Merkle proof verification tests

### Formatting

```bash
forge fmt
```

### Environment Setup

1. Copy the environment template:
   ```bash
   cp contracts/.env.example contracts/.env
   ```

2. Required environment variables in `contracts/.env`:
   - `PRIVATE_KEY`: Deployer private key
   - `RPC_URL`: RPC endpoint for deployment
   - `ETHERSCAN_API_KEY`: For contract verification
   - `REGISTRY_COORDINATOR`: EigenLayer registry coordinator address on target network

### Deployment

**Standard Deployment:**
```bash
# Deploy to specific network
forge script script/DeployEnvironment.s.sol:DeployEnvironment \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## E2E Testing Infrastructure

The `e2e/` directory contains Docker-based end-to-end testing infrastructure that simulates a full L1/L2 bridge deployment.

### E2E Architecture

**Components:**
- Local L1 fork (Ethereum/Sepolia) via Anvil
- Local L2 chain via Anvil
- Deployed EigenLayer contracts (from forked state)
- Deployed bridge contracts (MiddlewareShim on L1, RegistryCoordinatorMimic on L2)

**Configuration System:**
All e2e scripts source `e2e/docker/scripts/config.sh` which:
- Detects Docker vs local execution context
- Loads environment from `e2e/envs/bls-testnet.env`
- Provides path variables: `$SCRIPTS_DIR`, `$ARTIFACTS_DIR`, `$NODES_DIR`, `$FOUNDRY_ROOT_DIR`

### Running E2E Tests

**Using Docker (recommended):**
```bash
cd e2e/docker
./deploy-bls-testnet.sh
```

**E2E Scripts** (in `e2e/docker/scripts/`):
- `deploy-bridge.sh`: Deploys MiddlewareShim (L1) and RegistryCoordinatorMimic (L2)
- `update-shim.sh`: Updates L1 middleware data hash with current operator state
- `generate-proof.sh`: Generates Merkle proof of L1 storage
- `update-mimic.sh`: Updates L2 state with proof
- `run-check-signatures.sh`: Verifies BLS signature checking works with bridged state

**Deployment Artifacts:**
E2E deployments write JSON to `e2e/docker/artifacts/`:
- `l1-deploy.json`: L1 contract addresses
- `l2-deploy.json`: L2 contract addresses
- `middlewareDataProof.json`: Generated storage proof

### E2E Environment Variables

See `e2e/envs/bls-testnet.example.env` for full configuration. Key variables:
- `L1_RPC_URL`, `L2_RPC_URL`: RPC endpoints for the two chains
- `REGISTRY_COORDINATOR_ADDRESS`: EigenLayer registry on L1
- `SP1HELIOS_ADDRESS`: Light client contract on L2
- `IS_SP1HELIOS_MOCK`: Use mock proof verification for testing
- `DEPLOYER_KEY`: Private key for deployments

## Key Implementation Details

### MiddlewareShim Data Collection

The `getMiddlewareData()` function aggregates:
- **Operator keys**: G1/G2 BLS public keys from BLSApkRegistry
- **Quorum APK updates**: Aggregate public key history
- **Total stake history**: Per-quorum total stake over time
- **Operator stake history**: Per-operator stake snapshots
- **Operator bitmap history**: Quorum membership changes

All data is indexed to a specific L1 block number for verifiable snapshots.

### Assembly Usage for Gas Optimization

`RegistryCoordinatorMimic.updateState()` uses assembly to directly set storage array lengths:
```solidity
assembly {
    sstore(quorumApkUpdates.slot, quorumApkUpdatesLength)
}
```
This avoids expensive array resizing. Be cautious when modifying this logic.

### Proof Verification Flow

1. L1 storage proof is generated for the `middlewareDataHash` storage slot
2. Proof includes account proof and storage proof (RLP-encoded Merkle branches)
3. L2 contract verifies against SP1Helios light client's stored L1 state root
4. Uses Optimism's `SecureMerkleTrie` library for verification

### EigenLayer Middleware Integration

This codebase works with **EigenLayer M2 middleware** (pre-AllocationManager). When migrating to M3:
- Operator registration flow must change to use AllocationManager
- See `OpacityFork.t.sol` for current M2 registration patterns

## Working with this Codebase

### When Adding New Features

1. **Understand the two-chain split**: Decide if functionality belongs on L1 (data source) or L2 (mimic)
2. **Consider gas costs**: L2 state updates are expensive; assembly optimizations may be necessary
3. **Maintain interface compatibility**: The mimic should match EigenLayer's `IRegistryCoordinator` interface
4. **Test with fork tests**: Use `OpacityFork.t.sol` pattern to test against real deployments

### Common Gotchas

- The project currently has a build error in `DeployEnvironment.s.sol` referencing undefined constants
- `QuorumBitmapHistoryLib` is an external library requiring separate deployment (multi-chain scripts don't support library linking)
- Forge test listing may fail due to compilation errors but core contracts still work
- The codebase assumes single quorum (quorum 0) in many places; multi-quorum support is limited

### Architecture Notes

- **Quorum handling**: Most logic hardcoded for quorum 0 (`hex"00"`), multi-quorum is TODO
- **Incremental updates**: Currently full state replacement; incremental updates are TODO (see `updateState()` comments)
- **Staleness**: No enforcement that latest proof is used; older valid proofs are accepted
- **Gas limits**: `getMiddlewareData()` may exceed block gas limit with many operators (TODO comment present)
