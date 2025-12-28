# AVS Middleware Helm Chart

Kubernetes deployment for EigenLayer AVS middleware with cross-chain BLS signature verification.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Kind (for local testing)
- EigenLayer infrastructure deployed (via gas-killer-router)

## Installation

### Local Development

```bash
# Create Kind cluster and run E2E tests
./scripts/helm-e2e-test.sh run

# Cleanup
./scripts/helm-e2e-test.sh clean
```

### Manual Installation

```bash
# Add gas-killer-router submodule (if not already added)
git submodule update --init --recursive

# Deploy EigenLayer infrastructure first
helm install eigenlayer ./lib/gas-killer-router/helm/gas-killer \
  --namespace eigenlayer \
  --create-namespace \
  --set environment=LOCAL

# Get Registry Coordinator address
REGISTRY_COORDINATOR=$(kubectl get configmap eigenlayer-addresses \
  -n eigenlayer -o jsonpath='{.data.registryCoordinator}')

# Deploy AVS Middleware
helm install avs-middleware ./helm/avs-middleware \
  --namespace avs \
  --create-namespace \
  --set eigenlayer.registryCoordinator.address=$REGISTRY_COORDINATOR
```

### Sepolia + Gnosis Deployment

```bash
# Configure environment
cp e2e/envs/sepolia-gnosis.env .env
# Edit .env with your values

# Deploy with production settings
helm install avs-middleware ./helm/avs-middleware \
  --namespace avs \
  --create-namespace \
  --set environment=sepolia \
  --set eigenlayer.registryCoordinator.address=$REGISTRY_COORDINATOR_ADDRESS \
  --set sp1Helios.mock=false \
  --set sp1Helios.beaconChainRpc=$BEACON_CHAIN_RPC
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `environment` | Target environment (local, sepolia, holesky) | `local` |
| `network.l1.rpcUrl` | L1 RPC endpoint | `http://ethereum:8545` |
| `network.l2.rpcUrl` | L2 RPC endpoint | `http://gnosis:8545` |
| `eigenlayer.registryCoordinator.address` | Registry Coordinator address | `""` |
| `sp1Helios.mock` | Use SP1 Helios mock | `true` |
| `sp1Helios.address` | SP1 Helios contract address | `""` |
| `sp1Helios.beaconChainRpc` | Beacon chain RPC for proofs | `""` |
| `operators.count` | Number of operators | `3` |
| `signer.enabled` | Deploy Cerberus signer | `true` |
| `e2eTest.enabled` | Run E2E tests after deploy | `true` |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐      ┌─────────────────────────────┐   │
│  │  EigenLayer NS  │      │       AVS Namespace          │   │
│  │  ┌───────────┐  │      │  ┌───────────────────────┐   │   │
│  │  │ Ethereum  │  │      │  │    Cerberus Signer    │   │   │
│  │  │  (Anvil)  │  │      │  └───────────────────────┘   │   │
│  │  └───────────┘  │      │  ┌───────────────────────┐   │   │
│  │  ┌───────────┐  │      │  │    E2E Test Job       │   │   │
│  │  │  Setup    │  │      │  │  - deploy-bridge.sh   │   │   │
│  │  │   Job     │  │      │  │  - update-shim.sh     │   │   │
│  │  └───────────┘  │      │  │  - generate-proof.sh  │   │   │
│  │  ┌───────────┐  │      │  │  - update-mimic.sh    │   │   │
│  │  │ Operator  │  │      │  │  - check-signatures   │   │   │
│  │  │  Nodes    │  │      │  └───────────────────────┘   │   │
│  │  └───────────┘  │      │  ┌───────────────────────┐   │   │
│  └─────────────────┘      │  │   SP1 Helios (opt)    │   │   │
│                           │  └───────────────────────┘   │   │
│                           └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## E2E Test Flow

1. **Deploy Bridge Contracts** - MiddlewareShim (L1), RegistryCoordinatorMimic (L2)
2. **Update Shim** - Call `updateMiddlewareDataHash()` on L1
3. **Generate Proof** - Create Merkle proof for state verification
4. **Update Mimic** - Apply proof to L2 contract
5. **Verify Signatures** - Run BLS signature verification

## Operator Keys

Operator keys are stored in a PersistentVolumeClaim and include:

- `{operator}.bls.key.json` - BLS public key
- `{operator}.private.bls.key.json` - BLS private key (secure!)
- `{operator}.ecdsa.key.json` - ECDSA key pair

For production, store keys in Kubernetes Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: avs-operator-keys
type: Opaque
data:
  testacc1.private.bls.key.json: <base64-encoded>
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n avs
kubectl describe pod <pod-name> -n avs
```

### View E2E test logs
```bash
kubectl logs job/avs-middleware-e2e-test -n avs
```

### Check setup completion
```bash
kubectl exec -it <pod-name> -n eigenlayer -- ls -la /app/.nodes/
```
