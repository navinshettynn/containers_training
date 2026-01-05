#!/bin/bash

#######################################################################
# Kind (Kubernetes IN Docker) Installation Script for Ubuntu 24
# Prerequisites: Docker Community Edition must be installed
#######################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo_info "Detected architecture: $ARCH (kind binary: $KIND_ARCH)"

# Install required dependencies
echo_info "Installing required dependencies..."
apt-get update -qq
apt-get install -y -qq curl wget

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

# Verify installation
echo_info "Verifying kind installation..."
if kind version &> /dev/null; then
    echo_info "Kind installed successfully!"
    kind version
else
    echo_error "Kind installation failed."
    exit 1
fi

# Add kubectl installation prompt
echo ""
echo_info "==========================================="
echo_info "Kind installation complete!"
echo_info "==========================================="
echo ""
echo_info "Quick Start Guide:"
echo "  1. Create a cluster:    kind create cluster --name my-cluster"
echo "  2. List clusters:       kind get clusters"
echo "  3. Delete cluster:      kind delete cluster --name my-cluster"
echo ""
echo_warn "Note: Make sure kubectl is installed to interact with the cluster."
echo_info "Install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
echo ""

