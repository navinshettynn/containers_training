#!/bin/bash

#######################################################################
# Kind (Kubernetes IN Docker) + kubectl Installation Script for Ubuntu 24
# Prerequisites: Docker Community Edition must be installed
# This script will:
#   1. Install kind
#   2. Install kubectl
#   3. Create a 2-node Kubernetes cluster (1 control-plane + 1 worker)
#######################################################################

set -e  # Exit on any error

# Configuration
CLUSTER_NAME="kind-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo ""
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}[STEP]${NC} $1"
    echo -e "${BLUE}===================================================${NC}"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if Docker is installed
echo_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo_error "Docker is not installed. Please install Docker CE first."
    echo_info "Visit: https://docs.docker.com/engine/install/ubuntu/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo_error "Docker daemon is not running. Please start Docker first."
    echo_info "Run: sudo systemctl start docker"
    exit 1
fi

echo_info "Docker is installed and running."
docker --version

# Detect system architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        KIND_ARCH="amd64"
        ;;
    aarch64|arm64)
        KIND_ARCH="arm64"
        ;;
    *)
        echo_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo_info "Detected architecture: $ARCH (binary arch: $KIND_ARCH)"

# Install required dependencies
echo_info "Installing required dependencies..."
apt-get update -qq
apt-get install -y -qq curl wget apt-transport-https ca-certificates gnupg

#######################################################################
# STEP 1: Install Kind
#######################################################################
echo_step "Installing Kind"

# Get the latest kind version
echo_info "Fetching latest kind version..."
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$KIND_VERSION" ]]; then
    echo_warn "Could not fetch latest version. Using 'latest' tag."
    KIND_URL="https://kind.sigs.k8s.io/dl/latest/kind-linux-${KIND_ARCH}"
else
    echo_info "Latest kind version: $KIND_VERSION"
    KIND_URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}"
fi

# Download kind binary
echo_info "Downloading kind from: $KIND_URL"
curl -Lo /usr/local/bin/kind "$KIND_URL"

# Make kind executable
chmod +x /usr/local/bin/kind

# Verify kind installation
echo_info "Verifying kind installation..."
if kind version &> /dev/null; then
    echo_info "Kind installed successfully!"
    kind version
else
    echo_error "Kind installation failed."
    exit 1
fi

#######################################################################
# STEP 2: Install kubectl
#######################################################################
echo_step "Installing kubectl"

# Check if kubectl is already installed
if command -v kubectl &> /dev/null; then
    echo_info "kubectl is already installed."
    kubectl version --client --short 2>/dev/null || kubectl version --client
else
    echo_info "Downloading kubectl..."
    
    # Get the latest stable kubectl version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo_info "Latest kubectl version: $KUBECTL_VERSION"
    
    # Download kubectl binary
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KIND_ARCH}/kubectl"
    
    # Download checksum file
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KIND_ARCH}/kubectl.sha256"
    
    # Verify checksum
    echo_info "Verifying kubectl checksum..."
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Install kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Cleanup
    rm -f kubectl kubectl.sha256
    
    # Verify installation
    echo_info "kubectl installed successfully!"
    kubectl version --client
fi

#######################################################################
# STEP 3: Create 2-Node Kind Cluster
#######################################################################
echo_step "Creating 2-Node Kubernetes Cluster"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo_warn "Cluster '${CLUSTER_NAME}' already exists."
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Deleting existing cluster..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo_info "Keeping existing cluster. Skipping cluster creation."
        echo ""
        echo_info "==========================================="
        echo_info "Setup Complete!"
        echo_info "==========================================="
        echo ""
        echo_info "Existing cluster details:"
        kubectl cluster-info --context "kind-${CLUSTER_NAME}" 2>/dev/null || true
        exit 0
    fi
fi

# Create kind cluster configuration file
echo_info "Creating cluster configuration..."
cat > /tmp/kind-config.yaml <<EOF
# Kind cluster configuration - 2 Node Cluster
# 1 Control Plane + 1 Worker Node
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  # Control plane node
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      # Map container port 80 to host port 80 (for ingress)
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      # Map container port 443 to host port 443 (for ingress)
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  # Worker node
  - role: worker
EOF

echo_info "Cluster configuration:"
cat /tmp/kind-config.yaml

# Create the cluster
echo_info "Creating kind cluster '${CLUSTER_NAME}' with 2 nodes..."
echo_info "This may take a few minutes..."
kind create cluster --config /tmp/kind-config.yaml --wait 5m

# Cleanup config file
rm -f /tmp/kind-config.yaml

# Verify cluster is running
echo_info "Verifying cluster status..."
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo ""
echo_info "Cluster nodes:"
kubectl get nodes -o wide

echo ""
echo_info "All pods in kube-system namespace:"
kubectl get pods -n kube-system

#######################################################################
# Summary
#######################################################################
echo ""
echo -e "${GREEN}==========================================="
echo "  SETUP COMPLETE!"
echo "===========================================${NC}"
echo ""
echo -e "${GREEN}Installed:${NC}"
echo "  - kind:    $(kind version)"
echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1)"
echo ""
echo -e "${GREEN}Cluster Details:${NC}"
echo "  - Name:    ${CLUSTER_NAME}"
echo "  - Nodes:   2 (1 control-plane + 1 worker)"
echo "  - Context: kind-${CLUSTER_NAME}"
echo ""
echo -e "${GREEN}Useful Commands:${NC}"
echo "  kubectl get nodes              # List cluster nodes"
echo "  kubectl get pods -A            # List all pods"
echo "  kind get clusters              # List kind clusters"
echo "  kind delete cluster --name ${CLUSTER_NAME}  # Delete cluster"
echo ""
echo -e "${YELLOW}Note:${NC} Port 80 and 443 are mapped for ingress controller use."
echo ""

