# Bridge Docker Image

Docker image for bridging EigenLayer operator state from L1 to L2.

## Image

```
ghcr.io/ronturetzky/target-contracts/bridge:pr-1
```

## Usage

```bash
docker run --rm \
  -e PRIVATE_KEY="0x..." \
  -e L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY" \
  -e L2_RPC_URL="https://gnosis-mainnet.g.alchemy.com/v2/YOUR_KEY" \
  -e REGISTRY_COORDINATOR_ADDRESS="0x..." \
  ghcr.io/ronturetzky/target-contracts/bridge:pr-1
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | Yes | Private key for deployment transactions |
| `L1_RPC_URL` | Yes | RPC URL for L1 (Sepolia, Holesky, Mainnet) |
| `L2_RPC_URL` | Yes | RPC URL for L2 (Gnosis, Arbitrum, etc.) |
| `REGISTRY_COORDINATOR_ADDRESS` | Yes | EigenLayer registry coordinator address on L1 |
| `SLOT_NUMBER` | No | Slot number for mock proof (default: 12345) |
| `SKIP_DEPLOY` | No | Set to "true" to skip deployment and reuse existing contracts |
| `L1_DEPLOY_FILE` | No | Path to existing L1 deployment JSON (required if SKIP_DEPLOY=true) |
| `L2_DEPLOY_FILE` | No | Path to existing L2 deployment JSON (required if SKIP_DEPLOY=true) |

## Expected Logs

```
[INFO] Step 1: Deploying L1 contracts to https:...
[INFO] L1 contracts deployed. Output: /app/contracts/artifacts/l1-deploy.json
[INFO] MiddlewareShim: 0x...

[INFO] Step 2: Deploying L2 contracts...
[INFO] L2 contracts deployed. Output: /app/contracts/artifacts/l2-deploy.json
[INFO] RegistryCoordinatorMimic: 0x...
[INFO] BLSSignatureChecker: 0x...

[INFO] Step 3: Updating L1 MiddlewareShim (snapshotting operator state)...
[INFO] Transaction hash: 0x...
[INFO] Operator state snapshotted at block: 0x...

[INFO] Step 4: Generating mock proof...
[INFO] SP1Helios address: 0x...
[INFO] Middleware block number: ...
[INFO] Latest L1 block: 0x...
[INFO] Execution state root: 0x...
[INFO] Setting execution state root on SP1Helios mock...
[INFO] Mock proof saved to: /app/contracts/artifacts/middlewareDataProof.json

[INFO] Step 5: Bridging state to L2 mimic...
[INFO] State bridged successfully!

[INFO] Verifying bridged state on L2...
[INFO] Verification complete:
  - Quorum count: 1
  - Last updated block: ...

========================================
Bridge Complete!
========================================

L1 Contracts (eth-sepolia):
  MiddlewareShim: 0x...

L2 Contracts:
  RegistryCoordinatorMimic: 0x...
  BLSSignatureChecker: 0x...
  SP1HeliosMock: 0x...

Deployment files:
  L1: /app/contracts/artifacts/l1-deploy.json
  L2: /app/contracts/artifacts/l2-deploy.json
  Proof: /app/contracts/artifacts/middlewareDataProof.json
```

## What It Does

1. **Deploy L1 Contracts** - Deploys `MiddlewareShim` pointing to the registry coordinator
2. **Deploy L2 Contracts** - Deploys `SP1HeliosMock`, `RegistryCoordinatorMimic`, `BLSSignatureChecker`
3. **Update L1 Shim** - Calls `updateMiddlewareDataHash()` to snapshot operator state
4. **Generate Mock Proof** - Creates storage/account proofs and sets state root on mock
5. **Bridge State** - Updates L2 mimic with bridged operator state
