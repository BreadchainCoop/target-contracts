# Kubernetes Integration for Bridge

Deploy the EigenLayer state bridge as a Kubernetes Job.

## Docker Image

```
ghcr.io/ronturetzky/target-contracts/bridge:pr-1
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | Yes | Private key for deployment transactions |
| `L1_RPC_URL` | Yes | RPC URL for L1 (e.g., Sepolia, Mainnet) |
| `L2_RPC_URL` | Yes | RPC URL for L2 (e.g., Gnosis, Arbitrum) |
| `REGISTRY_COORDINATOR_ADDRESS` | Yes | EigenLayer registry coordinator on L1 |
| `SLOT_NUMBER` | No | Slot number for mock proof (default: 12345) |
| `SKIP_DEPLOY` | No | Set to "true" to reuse existing contracts |
| `L1_DEPLOY_FILE` | No | Path to existing L1 deployment JSON |
| `L2_DEPLOY_FILE` | No | Path to existing L2 deployment JSON |

## Setup

### 1. Create Namespace

```bash
kubectl create namespace eigenlayer-bridge
```

### 2. Create Secret for Private Key

```bash
kubectl create secret generic bridge-secrets \
  --namespace eigenlayer-bridge \
  --from-literal=PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
```

### 3. Create ConfigMap for Configuration

```bash
kubectl create configmap bridge-config \
  --namespace eigenlayer-bridge \
  --from-literal=L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY" \
  --from-literal=L2_RPC_URL="https://gnosis-mainnet.g.alchemy.com/v2/YOUR_KEY" \
  --from-literal=REGISTRY_COORDINATOR_ADDRESS="0x0b6c8481772e8fc6c6c495bc8d6f89d1f5df2c9d"
```

### 4. Run as a Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: bridge-job
  namespace: eigenlayer-bridge
spec:
  ttlSecondsAfterFinished: 86400
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: bridge
          image: ghcr.io/ronturetzky/target-contracts/bridge:pr-1
          env:
            - name: PRIVATE_KEY
              valueFrom:
                secretKeyRef:
                  name: bridge-secrets
                  key: PRIVATE_KEY
            - name: L1_RPC_URL
              valueFrom:
                configMapKeyRef:
                  name: bridge-config
                  key: L1_RPC_URL
            - name: L2_RPC_URL
              valueFrom:
                configMapKeyRef:
                  name: bridge-config
                  key: L2_RPC_URL
            - name: REGISTRY_COORDINATOR_ADDRESS
              valueFrom:
                configMapKeyRef:
                  name: bridge-config
                  key: REGISTRY_COORDINATOR_ADDRESS
            - name: FOUNDRY_DISABLE_NIGHTLY_WARNING
              value: "1"
          resources:
            requests:
              memory: "2Gi"
              cpu: "1"
            limits:
              memory: "4Gi"
              cpu: "2"
```

### 5. Run as a CronJob (Scheduled State Sync)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bridge-sync
  namespace: eigenlayer-bridge
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: bridge
              image: ghcr.io/ronturetzky/target-contracts/bridge:pr-1
              env:
                - name: PRIVATE_KEY
                  valueFrom:
                    secretKeyRef:
                      name: bridge-secrets
                      key: PRIVATE_KEY
                - name: L1_RPC_URL
                  valueFrom:
                    configMapKeyRef:
                      name: bridge-config
                      key: L1_RPC_URL
                - name: L2_RPC_URL
                  valueFrom:
                    configMapKeyRef:
                      name: bridge-config
                      key: L2_RPC_URL
                - name: REGISTRY_COORDINATOR_ADDRESS
                  valueFrom:
                    configMapKeyRef:
                      name: bridge-config
                      key: REGISTRY_COORDINATOR_ADDRESS
                - name: SKIP_DEPLOY
                  value: "true"
                - name: L1_DEPLOY_FILE
                  value: "/config/l1-deploy.json"
                - name: L2_DEPLOY_FILE
                  value: "/config/l2-deploy.json"
              volumeMounts:
                - name: deployment-config
                  mountPath: /config
          volumes:
            - name: deployment-config
              configMap:
                name: bridge-deployments
```

## Monitoring

```bash
# Watch job status
kubectl get jobs -n eigenlayer-bridge -w

# View logs
kubectl logs -n eigenlayer-bridge job/bridge-job -f

# Get deployed contract addresses from logs
kubectl logs -n eigenlayer-bridge job/bridge-job | grep -A 20 "Bridge Complete"
```

## Output

The bridge outputs deployed contract addresses:

```
L1 Contracts (Sepolia):
  MiddlewareShim: 0x...

L2 Contracts (Gnosis):
  RegistryCoordinatorMimic: 0x...
  BLSSignatureChecker: 0x...
  SP1HeliosMock: 0x...
```

## Cleanup

```bash
kubectl delete namespace eigenlayer-bridge
```
