# Middleware Contracts

Smart contracts for EigenLayer AVS middleware including MiddlewareShim, RegistryCoordinatorMimic, and BLS signature verification.

## Supported Networks

| Network | Status | RPC Endpoint |
|---------|--------|--------------|
| Holesky | Active | `https://1rpc.io/holesky` |
| Sepolia | Active | `https://1rpc.io/sepolia` |
| Mainnet | Reference only | - |

## Quick Start

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

## Deployment

### Holesky Deployment

1. Copy and configure environment:
```shell
cp .env.example .env
# Edit .env with your PRIVATE_KEY and RPC_URL
```

2. Deploy:
```shell
source .env
forge script script/DeployEnvironment.s.sol:DeployEnvironment \
  --rpc-url holesky \
  --broadcast
```

### Sepolia Deployment

1. Copy and configure environment:
```shell
cp .env.sepolia.example .env.sepolia
# Edit .env.sepolia with your PRIVATE_KEY and REGISTRY_COORDINATOR_ADDRESS
```

2. Deploy:
```shell
source .env.sepolia
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url sepolia \
  --broadcast
```

> **Optional:** Add `--verify --etherscan-api-key $ETHERSCAN_API_KEY` to verify contracts on Etherscan.

**Note:** You must have a Registry Coordinator deployed on Sepolia before running this script. Set `REGISTRY_COORDINATOR_ADDRESS` in your environment.

### EigenLayer Contract Addresses

#### Sepolia (v1.9.0-rc.0)

| Contract | Address |
|----------|---------|
| DelegationManager | `0xD4A7E1Bd8015057293f0D0A557088c286942e84b` |
| StrategyManager | `0x2E3D6c0744b10eb0A4e6F679F71554a39Ec47a5D` |
| EigenPodManager | `0x56BfEb94879F4543E756d26103976c567256034a` |
| AVSDirectory | `0xa789c91ECDdae96865913130B786140Ee17aF545` |
| RewardsCoordinator | `0x5ae8152fb88c26ff9ca5C014c94fca3c68029349` |
| AllocationManager | `0x42583067658071247ec8CE0A516A58f682002d07` |

> **Important:** All EigenPod functionality is PAUSED on Sepolia due to testnet validator restrictions.

#### Holesky

| Contract | Address |
|----------|---------|
| DelegationManager | `0xA44151489861Fe9e3055d95adC98FbD462B948e7` |
| StrategyManager | `0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6` |
| RegistryCoordinator (Opacity) | `0x3e43AA225b5cB026C5E8a53f62572b10D526a50B` |

## E2E Testing

For end-to-end testing with L1/L2 deployment flow, see the `e2e/` directory and use:
- `e2e/envs/bls-testnet.example.env` for Holesky
- `e2e/envs/sepolia.example.env` for Sepolia

## Contracts

- **MiddlewareShim**: Aggregates middleware data from EigenLayer's registry coordinator
- **RegistryCoordinatorMimic**: L2 contract that mimics L1 registry coordinator using SP1Helios proofs
- **BLSSignatureChecker**: Verifies BLS signatures from operators

## Foundry

Built with [Foundry](https://book.getfoundry.sh/).

```shell
forge --help
anvil --help
cast --help
```
