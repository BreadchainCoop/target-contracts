# Bridge Scripts

Scripts for bridging EigenLayer operator state from L1 to L2.

## bridge-to-l2.sh

Deploys bridge contracts and bridges operator state from an L1 registry coordinator to an L2 mimic contract using mock SP1Helios verification.

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- `cast` and `forge` available in PATH
- `jq` installed

### Usage

```bash
# Set required environment variables
export PRIVATE_KEY="0x..."
export L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
export L2_RPC_URL="https://gnosis-mainnet.g.alchemy.com/v2/YOUR_KEY"
export REGISTRY_COORDINATOR_ADDRESS="0x..."

# Run the bridge script
./scripts/bridge-to-l2.sh
```

Or use an env file:

```bash
cp scripts/bridge.env.example scripts/bridge.env
# Edit bridge.env with your values
source scripts/bridge.env && ./scripts/bridge-to-l2.sh
```

### What it does

1. **Deploy L1 Contracts** - Deploys `MiddlewareShim` pointing to the registry coordinator
2. **Deploy L2 Contracts** - Deploys `SP1HeliosMock`, `RegistryCoordinatorMimic`, `BLSSignatureChecker`
3. **Update L1 Shim** - Calls `updateMiddlewareDataHash()` to snapshot operator state
4. **Generate Mock Proof** - Creates storage/account proofs and sets state root on mock
5. **Bridge State** - Runs `UpdateMimic.s.sol` to bridge state to L2

### Skip Deployment

To use existing deployed contracts:

```bash
export SKIP_DEPLOY=true
export L1_DEPLOY_FILE=/path/to/l1-deploy.json
export L2_DEPLOY_FILE=/path/to/l2-deploy.json
./scripts/bridge-to-l2.sh
```

### Output

The script creates these files in `contracts/artifacts/`:
- `l1-deploy.json` - L1 contract addresses
- `l2-deploy.json` - L2 contract addresses
- `middlewareDataProof.json` - Generated storage proof
