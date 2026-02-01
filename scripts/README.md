# Bridge Docker Image

Docker image for bridging EigenLayer operator state from L1 to L2 using existing deployed contracts.

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
  -e MIDDLEWARE_SHIM_ADDRESS="0x..." \
  -e REGISTRY_COORDINATOR_MIMIC_ADDRESS="0x..." \
  -e BLS_SIGNATURE_CHECKER_ADDRESS="0x..." \
  ghcr.io/ronturetzky/target-contracts/bridge:pr-1
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | Yes | Private key for transactions |
| `L1_RPC_URL` | Yes | RPC URL for L1 (Sepolia, Holesky, Mainnet) |
| `L2_RPC_URL` | Yes | RPC URL for L2 (Gnosis, Arbitrum, etc.) |
| `MIDDLEWARE_SHIM_ADDRESS` | Yes | L1 MiddlewareShim contract address |
| `REGISTRY_COORDINATOR_MIMIC_ADDRESS` | Yes | L2 RegistryCoordinatorMimic address |
| `BLS_SIGNATURE_CHECKER_ADDRESS` | Yes | L2 BLSSignatureChecker address |
| `SLOT_NUMBER` | No | Slot number for mock proof (default: 12345) |

## Expected Logs

```
[INFO] Step 1: Updating L1 MiddlewareShim (snapshotting operator state)...
[INFO] MiddlewareShim: 0x...
[INFO] Transaction hash: 0x...
[INFO] Operator state snapshotted at block: 0x...

[INFO] Step 2: Generating mock proof...
[INFO] SP1Helios address: 0x...
[INFO] Middleware block number: ...
[INFO] Latest L1 block: 0x...
[INFO] Execution state root: 0x...
[INFO] Setting execution state root on SP1Helios mock...
[INFO] Mock proof saved to: /app/contracts/artifacts/middlewareDataProof.json

[INFO] Step 3: Bridging state to L2 mimic...
[INFO] RegistryCoordinatorMimic: 0x...
[INFO] BLSSignatureChecker: 0x...
[INFO] State bridged successfully!

[INFO] Verifying bridged state on L2...
[INFO] Verification complete:
  - Quorum count: 1
  - Last updated block: ...

========================================
Bridge Complete!
========================================

L1 Contracts:
  MiddlewareShim: 0x...

L2 Contracts:
  RegistryCoordinatorMimic: 0x...
  BLSSignatureChecker: 0x...
  SP1HeliosMock: 0x...
```

## What It Does

1. **Update L1 Shim** - Calls `updateMiddlewareDataHash()` to snapshot current operator state
2. **Generate Mock Proof** - Creates storage/account proofs and sets state root on SP1Helios mock
3. **Bridge State** - Updates L2 RegistryCoordinatorMimic with bridged operator state
