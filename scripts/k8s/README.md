# Kubernetes Integration for Bridge

Deploy the EigenLayer state bridge as a Kubernetes Job.

## Prerequisites

- Kubernetes cluster with `kubectl` configured
- Access to `ghcr.io/ronturetzky/target-contracts/bridge` image

## Quick Start

```bash
# 1. Create namespace
kubectl create namespace eigenlayer-bridge

# 2. Create secret with private key
kubectl create secret generic bridge-secrets \
  --namespace eigenlayer-bridge \
  --from-literal=PRIVATE_KEY="0x..."

# 3. Create configmap with RPC URLs
kubectl create configmap bridge-config \
  --namespace eigenlayer-bridge \
  --from-literal=L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY" \
  --from-literal=L2_RPC_URL="https://gnosis-mainnet.g.alchemy.com/v2/YOUR_KEY" \
  --from-literal=REGISTRY_COORDINATOR_ADDRESS="0x..."

# 4. Apply the job
kubectl apply -f bridge-job.yaml
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | Yes | Private key for deployment transactions |
| `L1_RPC_URL` | Yes | RPC URL for L1 (e.g., Sepolia, Mainnet) |
| `L2_RPC_URL` | Yes | RPC URL for L2 (e.g., Gnosis, Arbitrum) |
| `REGISTRY_COORDINATOR_ADDRESS` | Yes | EigenLayer registry coordinator on L1 |
| `SLOT_NUMBER` | No | Slot number for mock proof (default: 12345) |
| `SKIP_DEPLOY` | No | Set to "true" to skip deployment |
| `L1_DEPLOY_FILE` | No | Path to existing L1 deployment JSON |
| `L2_DEPLOY_FILE` | No | Path to existing L2 deployment JSON |

## Manifests

See the YAML files in this directory:

- `bridge-job.yaml` - One-time bridge execution
- `bridge-cronjob.yaml` - Scheduled bridge updates (for state sync)

## Monitoring

```bash
# Watch job status
kubectl get jobs -n eigenlayer-bridge -w

# View logs
kubectl logs -n eigenlayer-bridge job/bridge-job

# Get pod status
kubectl get pods -n eigenlayer-bridge
```

## Extracting Deployment Artifacts

The bridge outputs deployment addresses to stdout. To capture them:

```bash
kubectl logs -n eigenlayer-bridge job/bridge-job | grep -A 20 "Bridge Complete"
```

## Cleanup

```bash
kubectl delete namespace eigenlayer-bridge
```
