#!/bin/bash

#######################################################################
# Bridge EigenLayer Operator State from L1 to L2
#
# This script bridges operator state from an L1 MiddlewareShim to an
# L2 RegistryCoordinatorMimic using existing deployed contracts.
#
# Required Environment Variables:
#   PRIVATE_KEY                      - Private key for transactions
#   L1_RPC_URL                       - RPC URL for L1 (e.g., Sepolia)
#   L2_RPC_URL                       - RPC URL for L2 (e.g., Gnosis)
#   MIDDLEWARE_SHIM_ADDRESS          - L1 MiddlewareShim contract address
#   REGISTRY_COORDINATOR_MIMIC_ADDRESS - L2 RegistryCoordinatorMimic address
#   BLS_SIGNATURE_CHECKER_ADDRESS    - L2 BLSSignatureChecker address
#
# Optional Environment Variables:
#   SLOT_NUMBER                      - Slot number for mock proof (default: 12345)
#
#######################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
validate_env() {
    local missing=()

    [[ -z "$PRIVATE_KEY" ]] && missing+=("PRIVATE_KEY")
    [[ -z "$L1_RPC_URL" ]] && missing+=("L1_RPC_URL")
    [[ -z "$L2_RPC_URL" ]] && missing+=("L2_RPC_URL")
    [[ -z "$MIDDLEWARE_SHIM_ADDRESS" ]] && missing+=("MIDDLEWARE_SHIM_ADDRESS")
    [[ -z "$REGISTRY_COORDINATOR_MIMIC_ADDRESS" ]] && missing+=("REGISTRY_COORDINATOR_MIMIC_ADDRESS")
    [[ -z "$BLS_SIGNATURE_CHECKER_ADDRESS" ]] && missing+=("BLS_SIGNATURE_CHECKER_ADDRESS")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
}

# Get script directory and set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/../contracts" && pwd)"
ARTIFACTS_DIR="$CONTRACTS_DIR/artifacts"

# Default values
SLOT_NUMBER="${SLOT_NUMBER:-12345}"

# Validate environment
validate_env

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

PROOF_FILE="$ARTIFACTS_DIR/middlewareDataProof.json"

cd "$CONTRACTS_DIR"

#######################################################################
# Step 1: Update L1 Shim (Snapshot operator state)
#######################################################################

log_info "Step 1: Updating L1 MiddlewareShim (snapshotting operator state)..."
log_info "MiddlewareShim: $MIDDLEWARE_SHIM_ADDRESS"

TX_RESULT=$(cast send \
    --rpc-url "$L1_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json \
    "$MIDDLEWARE_SHIM_ADDRESS" \
    "updateMiddlewareDataHash()")

TX_HASH=$(echo "$TX_RESULT" | jq -r '.transactionHash')
log_info "Transaction hash: $TX_HASH"

# Wait for confirmation
sleep 3

BLOCK_NUMBER=$(cast receipt --rpc-url "$L1_RPC_URL" "$TX_HASH" --json | jq -r '.blockNumber')
log_info "Operator state snapshotted at block: $BLOCK_NUMBER"

#######################################################################
# Step 2: Generate Mock Proof
#######################################################################

log_info "Step 2: Generating mock proof..."

# Get SP1Helios address from mimic
SP1HELIOS_ADDRESS=$(cast call "$REGISTRY_COORDINATOR_MIMIC_ADDRESS" "LITE_CLIENT()(address)" --rpc-url "$L2_RPC_URL")
log_info "SP1Helios address: $SP1HELIOS_ADDRESS"

# Get middleware block number
MIDDLEWARE_BLOCK_NUMBER=$(cast call "$MIDDLEWARE_SHIM_ADDRESS" "lastBlockNumber()" --rpc-url "$L1_RPC_URL" | cast to-dec)
log_info "Middleware block number: $MIDDLEWARE_BLOCK_NUMBER"

# Get latest block and proof data
LATEST_BLOCK=$(cast block latest --rpc-url "$L1_RPC_URL" --json | jq -r '.number')
log_info "Latest L1 block: $LATEST_BLOCK"

# Get storage proof for slot 0 (middlewareDataHash)
STORAGE_SLOT=0
PROOF_DATA=$(cast proof -B "$LATEST_BLOCK" "$MIDDLEWARE_SHIM_ADDRESS" "$STORAGE_SLOT" --json --rpc-url "$L1_RPC_URL")

# Get execution state root
EXECUTION_STATE_ROOT=$(cast block "$LATEST_BLOCK" --rpc-url "$L1_RPC_URL" --json | jq -r '.stateRoot')
log_info "Execution state root: $EXECUTION_STATE_ROOT"

# Set execution state root on SP1Helios mock
log_info "Setting execution state root on SP1Helios mock..."
cast send "$SP1HELIOS_ADDRESS" \
    "setExecutionStateRoot(uint256,bytes32)" \
    "$SLOT_NUMBER" \
    "$EXECUTION_STATE_ROOT" \
    --rpc-url "$L2_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    > /dev/null 2>&1

# Create proof JSON file
jq -n \
    --arg middlewareBlockNumber "$MIDDLEWARE_BLOCK_NUMBER" \
    --arg slotNumber "$SLOT_NUMBER" \
    --arg storageHash "$(echo "$PROOF_DATA" | jq -r '.storageHash')" \
    --arg executionStateRoot "$EXECUTION_STATE_ROOT" \
    --argjson storageProof "$(echo "$PROOF_DATA" | jq -r '.storageProof[0].proof')" \
    --argjson accountProof "$(echo "$PROOF_DATA" | jq -r '.accountProof')" \
    '{
        "middlewareBlockNumber": $middlewareBlockNumber,
        "slotNumber": $slotNumber,
        "storageHash": $storageHash,
        "executionStateRoot": $executionStateRoot,
        "storageProof": $storageProof,
        "accountProof": $accountProof
    }' > "$PROOF_FILE"

log_info "Mock proof saved to: $PROOF_FILE"

#######################################################################
# Step 3: Update L2 Mimic (Bridge state)
#######################################################################

log_info "Step 3: Bridging state to L2 mimic..."
log_info "RegistryCoordinatorMimic: $REGISTRY_COORDINATOR_MIMIC_ADDRESS"
log_info "BLSSignatureChecker: $BLS_SIGNATURE_CHECKER_ADDRESS"

export PROOF_FILE
export REGISTRY_COORDINATOR_MIMIC_ADDRESS
export BLS_SIGNATURE_CHECKER_ADDRESS
export MIDDLEWARE_SHIM_ADDRESS
export IS_SP1HELIOS_MOCK="true"
export L1_RPC_URL
export L2_RPC_URL
export PRIVATE_KEY

forge script script/e2e/UpdateMimic.s.sol:UpdateMimic \
    --broadcast \
    --quiet

log_info "State bridged successfully!"

#######################################################################
# Verify bridged state
#######################################################################

log_info "Verifying bridged state on L2..."

QUORUM_COUNT=$(cast call "$REGISTRY_COORDINATOR_MIMIC_ADDRESS" "quorumCount()(uint8)" --rpc-url "$L2_RPC_URL")
LAST_BLOCK=$(cast call "$REGISTRY_COORDINATOR_MIMIC_ADDRESS" "lastBlockNumber()(uint32)" --rpc-url "$L2_RPC_URL")

log_info "Verification complete:"
echo "  - Quorum count: $QUORUM_COUNT"
echo "  - Last updated block: $LAST_BLOCK"

#######################################################################
# Summary
#######################################################################

echo ""
echo "========================================"
echo "Bridge Complete!"
echo "========================================"
echo ""
echo "L1 Contracts:"
echo "  MiddlewareShim: $MIDDLEWARE_SHIM_ADDRESS"
echo ""
echo "L2 Contracts:"
echo "  RegistryCoordinatorMimic: $REGISTRY_COORDINATOR_MIMIC_ADDRESS"
echo "  BLSSignatureChecker: $BLS_SIGNATURE_CHECKER_ADDRESS"
echo "  SP1HeliosMock: $SP1HELIOS_ADDRESS"
echo ""
