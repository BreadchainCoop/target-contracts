#!/bin/bash
# E2E Test Script for AVS Middleware with Helm
# This script runs a full end-to-end test using Kind cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-avs-e2e}"
NAMESPACE="${NAMESPACE:-avs}"
EIGENLAYER_NAMESPACE="${EIGENLAYER_NAMESPACE:-eigenlayer}"
ENVIRONMENT="${ENVIRONMENT:-local}"
SP1_MOCK="${SP1_MOCK:-true}"
TIMEOUT="${TIMEOUT:-600}"

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

# Check required tools
check_requirements() {
    log_info "Checking requirements..."

    local missing=()
    command -v kind >/dev/null 2>&1 || missing+=("kind")
    command -v helm >/dev/null 2>&1 || missing+=("helm")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v docker >/dev/null 2>&1 || missing+=("docker")

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with:"
        log_info "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        log_info "  - helm: https://helm.sh/docs/intro/install/"
        log_info "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi

    log_info "All requirements satisfied"
}

# Create Kind cluster
create_cluster() {
    log_info "Creating Kind cluster: $CLUSTER_NAME"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster $CLUSTER_NAME already exists, deleting..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi

    kind create cluster --name "$CLUSTER_NAME" --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
    extraMounts:
      - hostPath: ${PROJECT_ROOT}/e2e/docker/.nodes
        containerPath: /nodes
EOF

    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    log_info "Cluster created successfully"
}

# Build and load Docker image
build_and_load_image() {
    log_info "Building E2E Docker image..."

    cd "$PROJECT_ROOT"
    docker build -t avs-middleware-e2e:latest -f e2e/docker/Dockerfile .

    log_info "Loading image into Kind cluster..."
    kind load docker-image avs-middleware-e2e:latest --name "$CLUSTER_NAME"

    log_info "Image loaded successfully"
}

# Deploy EigenLayer infrastructure
deploy_eigenlayer() {
    log_info "Deploying EigenLayer infrastructure..."

    # Check if gas-killer-router submodule exists
    if [ ! -d "$PROJECT_ROOT/lib/gas-killer-router" ]; then
        log_warn "gas-killer-router submodule not found, cloning..."
        git clone --depth 1 https://github.com/BreadchainCoop/gas-killer-router.git "$PROJECT_ROOT/lib/gas-killer-router"
    fi

    # Deploy EigenLayer helm chart
    helm upgrade --install eigenlayer "$PROJECT_ROOT/lib/gas-killer-router/helm/gas-killer" \
        --namespace "$EIGENLAYER_NAMESPACE" \
        --create-namespace \
        --set environment=LOCAL \
        --set ethereum.enabled=true \
        --set setupJob.enabled=true \
        --set node.count=3 \
        --wait \
        --timeout="${TIMEOUT}s"

    log_info "Waiting for EigenLayer setup job..."
    kubectl wait --for=condition=complete job/eigenlayer-setup \
        --namespace "$EIGENLAYER_NAMESPACE" \
        --timeout="${TIMEOUT}s" || {
            log_error "EigenLayer setup job failed"
            kubectl logs job/eigenlayer-setup -n "$EIGENLAYER_NAMESPACE"
            exit 1
        }

    log_info "EigenLayer infrastructure deployed"
}

# Deploy AVS Middleware
deploy_avs_middleware() {
    log_info "Deploying AVS Middleware..."

    # Get Registry Coordinator address
    local registry_coordinator
    registry_coordinator=$(kubectl get configmap eigenlayer-addresses \
        -n "$EIGENLAYER_NAMESPACE" \
        -o jsonpath='{.data.registryCoordinator}' 2>/dev/null || echo "")

    if [ -z "$registry_coordinator" ]; then
        log_warn "Registry Coordinator address not found, using placeholder"
        registry_coordinator="0x0000000000000000000000000000000000000000"
    fi

    # Deploy AVS Middleware helm chart
    helm upgrade --install avs-middleware "$PROJECT_ROOT/helm/avs-middleware" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set environment="$ENVIRONMENT" \
        --set eigenlayer.registryCoordinator.address="$registry_coordinator" \
        --set sp1Helios.mock="$SP1_MOCK" \
        --set e2eTest.enabled=true \
        --wait \
        --timeout="${TIMEOUT}s"

    log_info "AVS Middleware deployed"
}

# Wait for E2E tests to complete
wait_for_tests() {
    log_info "Waiting for E2E tests to complete..."

    kubectl wait --for=condition=complete job/avs-middleware-e2e-test \
        --namespace "$NAMESPACE" \
        --timeout="${TIMEOUT}s" || {
            log_error "E2E tests failed"
            kubectl logs job/avs-middleware-e2e-test -n "$NAMESPACE"
            exit 1
        }

    log_info "E2E tests completed successfully!"
}

# Collect logs
collect_logs() {
    log_info "Collecting logs..."

    local log_dir="$PROJECT_ROOT/e2e/logs"
    mkdir -p "$log_dir"

    kubectl logs job/avs-middleware-e2e-test -n "$NAMESPACE" > "$log_dir/e2e-test.log" 2>&1 || true
    kubectl get pods -A -o wide > "$log_dir/pods-status.txt" 2>&1 || true
    kubectl get events -A --sort-by='.lastTimestamp' > "$log_dir/events.txt" 2>&1 || true

    log_info "Logs collected in $log_dir"
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."

    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true

    log_info "Cleanup complete"
}

# Main execution
main() {
    local action="${1:-run}"

    case "$action" in
        run)
            check_requirements
            create_cluster
            build_and_load_image
            deploy_eigenlayer
            deploy_avs_middleware
            wait_for_tests
            collect_logs
            log_info "All E2E tests passed!"
            ;;
        clean)
            cleanup
            ;;
        logs)
            collect_logs
            ;;
        *)
            echo "Usage: $0 {run|clean|logs}"
            echo ""
            echo "Commands:"
            echo "  run    - Run full E2E test suite"
            echo "  clean  - Delete Kind cluster and cleanup"
            echo "  logs   - Collect logs from running cluster"
            echo ""
            echo "Environment Variables:"
            echo "  CLUSTER_NAME    - Kind cluster name (default: avs-e2e)"
            echo "  NAMESPACE       - Kubernetes namespace for AVS (default: avs)"
            echo "  ENVIRONMENT     - Target environment: local, sepolia, holesky (default: local)"
            echo "  SP1_MOCK        - Use SP1 Helios mock: true, false (default: true)"
            echo "  TIMEOUT         - Timeout in seconds (default: 600)"
            exit 1
            ;;
    esac
}

# Handle signals
trap cleanup EXIT INT TERM

main "$@"
