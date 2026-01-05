# Environment Setup Guide

This guide provides step-by-step instructions to set up a local Kubernetes development environment using Kind (Kubernetes IN Docker) on Ubuntu 24.

## Prerequisites

Before you begin, ensure you have the following:

| Requirement | Description |
|-------------|-------------|
| **Operating System** | Ubuntu 24.04 LTS |
| **Docker CE** | Docker Community Edition installed and running |
| **Git** | Git installed for cloning the repository |
| **sudo access** | Administrative privileges on your system |

### Installing Docker CE (if not installed)

If Docker is not installed, follow the official Docker installation guide:
- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

Quick installation commands:

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CE
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
```

---

## Step 1: Clone the Repository

Open a terminal and clone the containers training repository:

```bash
git clone https://github.com/abhimanyusinghal/containers_training.git
```

Navigate to the cloned directory:

```bash
cd containers_training
```

---

## Step 2: Run the Kind Installation Script

The repository includes a script that will:
1. Install **Kind** (Kubernetes IN Docker)
2. Install **kubectl** (Kubernetes CLI)
3. Create a **2-node Kubernetes cluster** (1 control-plane + 1 worker)
4. Configure your user for sudo-free access

### Make the script executable and run it:

```bash
# Make the script executable
chmod +x install_kind.sh

# Run the script with sudo
sudo ./install_kind.sh
```

The script will take a few minutes to complete. You'll see progress updates as it:
- Verifies Docker installation
- Adds your user to the docker group
- Downloads and installs Kind
- Downloads and installs kubectl
- Creates the Kubernetes cluster
- Configures kubectl for your user

---

## Step 3: Activate Docker Group (if newly added)

If the script added you to the `docker` group, you need to activate it:

**Option 1:** Log out and log back in

**Option 2:** Run this command in your terminal:

```bash
newgrp docker
```

---

## Step 4: Verify the Installation

After the script completes, verify everything is working:

```bash
# Check Kind version
kind version

# Check kubectl version
kubectl version --client

# List cluster nodes
kubectl get nodes

# List all pods
kubectl get pods -A

# View cluster information
kubectl cluster-info
```

### Expected Output

You should see 2 nodes:

```
NAME                         STATUS   ROLES           AGE   VERSION
kind-cluster-control-plane   Ready    control-plane   5m    v1.x.x
kind-cluster-worker          Ready    <none>          5m    v1.x.x
```

---

## Cluster Details

| Property | Value |
|----------|-------|
| **Cluster Name** | kind-cluster |
| **Nodes** | 2 (1 control-plane + 1 worker) |
| **kubectl Context** | kind-kind-cluster |
| **Host Port 80** | Mapped (for Ingress) |
| **Host Port 443** | Mapped (for Ingress) |

---

## Useful Commands

### Cluster Management

```bash
# List all Kind clusters
kind get clusters

# Delete the cluster
kind delete cluster --name kind-cluster

# Recreate the cluster (run the script again)
sudo ./install_kind.sh
```

### kubectl Basics

```bash
# Get all resources in all namespaces
kubectl get all -A

# Get nodes with details
kubectl get nodes -o wide

# Get pods in kube-system namespace
kubectl get pods -n kube-system

# Describe a node
kubectl describe node kind-cluster-control-plane
```

### Docker Commands (for Kind nodes)

```bash
# List Kind containers (nodes)
docker ps --filter "name=kind"

# View logs of a Kind node
docker logs kind-cluster-control-plane
```

---

## Troubleshooting

### Docker daemon not running

```bash
sudo systemctl start docker
sudo systemctl status docker
```

### Permission denied for Docker

```bash
# Add yourself to docker group
sudo usermod -aG docker $USER

# Activate the group
newgrp docker
```

### Cluster creation fails

```bash
# Check Docker resources
docker system df

# Clean up unused Docker resources
docker system prune -a

# Check available disk space
df -h
```

### kubectl can't connect to cluster

```bash
# Check if kubeconfig exists
ls -la ~/.kube/config

# Verify cluster context
kubectl config get-contexts

# Switch to the Kind context
kubectl config use-context kind-kind-cluster
```


---

## Support

For issues with:
- **Kind**: [Kind Documentation](https://kind.sigs.k8s.io/)
- **kubectl**: [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- **Docker**: [Docker Documentation](https://docs.docker.com/)

