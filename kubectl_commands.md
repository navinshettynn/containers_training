# Common kubectl Commands – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. You are logged in as a regular user (not root)

### Verify Your Cluster is Running

```bash
# Check if kind cluster exists
kind get clusters

# Verify kubectl can communicate with the cluster
kubectl cluster-info

# Check nodes are ready
kubectl get nodes
```

You should see output similar to:

```
NAME                         STATUS   ROLES           AGE   VERSION
kind-cluster-control-plane   Ready    control-plane   10m   v1.29.0
kind-cluster-worker          Ready    <none>          10m   v1.29.0
```

### Copy-Paste Tip

When copying commands from this document:

- **Linux Terminal**: Use `Ctrl + Shift + V` to paste
- **SSH Clients**: Use right-click or your client's paste shortcut
- Ensure there are no trailing spaces or special characters

---

## Learning Objectives

- Understand **namespaces** and how to work with them
- Use **contexts** to switch between configurations
- **View Kubernetes objects** using various output formats
- **Create, update, and delete** objects using kubectl
- Apply **labels and annotations** to objects
- Use **debugging commands** to troubleshoot containers
- Understand **cluster management** commands
- Enable **command autocompletion** for productivity

### Intermediate Objectives (Optional)

- Use **JSONPath** to extract specific fields from objects
- Understand **port-forwarding** for debugging services
- Monitor **resource usage** with top command
- Manage node scheduling with **cordon** and **drain**

---

## Quick Sanity Check

Verify kubectl is installed and configured:

```bash
kubectl version --client
kubectl config current-context
```

You should see:

```
Client Version: v1.xx.x
...
kind-kind-cluster
```

List all resources in the cluster:

```bash
kubectl get all -A
```

This shows all running resources across all namespaces.

---

## Part 1: Understanding Namespaces

Kubernetes uses namespaces to organize objects in the cluster. Think of each namespace as a folder that holds a set of objects.

### List All Namespaces

```bash
kubectl get namespaces
```

Or use the short form:

```bash
kubectl get ns
```

You should see default namespaces:

| Namespace | Purpose |
|-----------|---------|
| `default` | Default namespace for user objects |
| `kube-system` | Kubernetes system components |
| `kube-public` | Publicly readable resources |
| `kube-node-lease` | Node heartbeat data |
| `local-path-storage` | KIND's default storage provisioner |

### View Resources in a Specific Namespace

```bash
# View pods in kube-system namespace
kubectl get pods --namespace=kube-system

# Using the shorthand -n flag
kubectl get pods -n kube-system
```

### View Resources Across All Namespaces

```bash
kubectl get pods --all-namespaces

# Or use the shorthand
kubectl get pods -A
```

### Create a Custom Namespace

```bash
kubectl create namespace dev
kubectl create namespace staging
```

### Verify Namespaces Were Created

```bash
kubectl get namespaces | grep -E "dev|staging"
```

### Run a Pod in a Specific Namespace

```bash
kubectl run nginx-dev --image=nginx:alpine -n dev
kubectl run nginx-staging --image=nginx:alpine -n staging
```

### Verify Pods in Different Namespaces

```bash
# This shows nothing (default namespace is empty)
kubectl get pods

# These show the pods we created
kubectl get pods -n dev
kubectl get pods -n staging
```

### Observation

By default, kubectl operates on the `default` namespace. You must specify `--namespace` or `-n` to work with other namespaces.

---

## Part 2: Working with Contexts

Contexts allow you to change the default namespace and cluster configuration permanently (until changed again).

### View Current Context

```bash
kubectl config current-context
```

### List All Available Contexts

```bash
kubectl config get-contexts
```

The `*` indicates the currently active context.

### View Context Details

```bash
kubectl config view
```

This shows the full kubeconfig, including clusters, users, and contexts.

### Create a New Context for the Dev Namespace

```bash
kubectl config set-context dev-context \
  --cluster=kind-kind-cluster \
  --user=kind-kind-cluster \
  --namespace=dev
```

### Switch to the New Context

```bash
kubectl config use-context dev-context
```

### Verify the Context Switch

```bash
kubectl config current-context
```

### Test the New Default Namespace

```bash
# Now this shows pods in dev namespace by default
kubectl get pods
```

You should see `nginx-dev` without specifying `-n dev`.

### Switch Back to Original Context

```bash
kubectl config use-context kind-kind-cluster
```

### Delete the Custom Context

```bash
kubectl config delete-context dev-context
```

---

## Part 3: Viewing Kubernetes Objects

The `get` command is the most basic way to view Kubernetes objects.

### Basic Get Commands

```bash
# List all pods in current namespace
kubectl get pods

# List all pods with more details
kubectl get pods -o wide

# List a specific pod
kubectl get pod nginx-dev -n dev
```

### Output Formats

kubectl supports multiple output formats:

| Flag | Description |
|------|-------------|
| `-o wide` | Additional columns (node, IP, etc.) |
| `-o yaml` | Full object definition in YAML |
| `-o json` | Full object definition in JSON |
| `-o name` | Only resource names |
| `--no-headers` | Remove header row |

### View Pod as YAML

```bash
kubectl get pod nginx-dev -n dev -o yaml
```

### View Pod as JSON

```bash
kubectl get pod nginx-dev -n dev -o json
```

### Remove Headers (Useful for Scripting)

```bash
kubectl get pods -n dev --no-headers
```

### View Multiple Resource Types

```bash
kubectl get pods,services,deployments -n kube-system
```

### Using JSONPath to Extract Specific Fields

Extract the pod IP address:

```bash
kubectl get pod nginx-dev -n dev -o jsonpath='{.status.podIP}'
```

Extract the node where the pod is running:

```bash
kubectl get pod nginx-dev -n dev -o jsonpath='{.spec.nodeName}'
```

List all pod names in a namespace:

```bash
kubectl get pods -n kube-system -o jsonpath='{.items[*].metadata.name}'
```

### Describe Command for Detailed Information

```bash
kubectl describe pod nginx-dev -n dev
```

This provides:

- Pod metadata (name, namespace, labels)
- Container specifications
- Current status and conditions
- Events related to the pod

### Explain Command for API Reference

```bash
# Get information about the Pod resource
kubectl explain pods

# Get information about a specific field
kubectl explain pods.spec

# Get information about containers
kubectl explain pods.spec.containers
```

### Watch for Changes

Monitor pods in real-time:

```bash
kubectl get pods -n dev --watch
```

Press `Ctrl+C` to stop watching.

---

## Part 4: Creating Objects with YAML Files

Kubernetes objects are defined as YAML or JSON files and created using `kubectl apply`.

### Create a Directory for Lab Files

```bash
mkdir -p ~/k8s-lab
cd ~/k8s-lab
```

### Create a Simple Pod Definition

```bash
cat > simple-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lab-nginx
  namespace: default
  labels:
    app: web
    environment: lab
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF
```

### Create the Pod

```bash
kubectl apply -f simple-pod.yaml
```

### Verify the Pod is Running

```bash
kubectl get pods lab-nginx
kubectl get pods lab-nginx -o wide
```

### Use Dry-Run to Preview Changes

```bash
kubectl apply -f simple-pod.yaml --dry-run=client
```

This shows what would happen without actually making changes.

### Server-Side Dry-Run

```bash
kubectl apply -f simple-pod.yaml --dry-run=server
```

This validates against the API server without creating the object.

---

## Part 5: Updating Objects

### Modify the YAML File

```bash
cat > simple-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lab-nginx
  namespace: default
  labels:
    app: web
    environment: lab
    version: "2.0"
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF
```

### Apply the Update

```bash
kubectl apply -f simple-pod.yaml
```

Note: Some pod fields are immutable after creation. Labels can be changed, but container specs cannot be changed without recreating the pod.

### View Last Applied Configuration

```bash
kubectl apply view-last-applied -f simple-pod.yaml
```

### Interactive Editing

```bash
kubectl edit pod lab-nginx
```

This opens the pod definition in your default editor (usually `vi`). Save and exit to apply changes.

**Tip**: Set your preferred editor:

```bash
export KUBE_EDITOR="nano"
kubectl edit pod lab-nginx
```

---

## Part 6: Deleting Objects

### Delete Using the YAML File

```bash
kubectl delete -f simple-pod.yaml
```

### Delete Using Resource Name

```bash
# First, recreate the pod
kubectl apply -f simple-pod.yaml

# Then delete it by name
kubectl delete pod lab-nginx
```

### Delete All Pods in a Namespace

```bash
kubectl delete pods --all -n dev
```

### Delete a Namespace (and All Its Contents)

```bash
kubectl delete namespace staging
```

**Warning**: This deletes everything in the namespace immediately. There is no confirmation prompt.

---

## Part 7: Labels and Annotations

Labels are key-value pairs used to organize and select objects. Annotations are for storing non-identifying metadata.

### Create Pods for Labeling Practice

```bash
kubectl run app1 --image=alpine --command -- sleep 3600
kubectl run app2 --image=alpine --command -- sleep 3600
kubectl run app3 --image=alpine --command -- sleep 3600
```

### Add Labels to Pods

```bash
kubectl label pods app1 environment=production
kubectl label pods app2 environment=development
kubectl label pods app3 environment=production
```

### View Labels

```bash
kubectl get pods --show-labels
```

### Filter by Label (Label Selector)

```bash
# Get pods with specific label
kubectl get pods -l environment=production

# Get pods that have a label (any value)
kubectl get pods -l environment

# Get pods without a specific label
kubectl get pods -l '!environment'
```

### Update an Existing Label

```bash
kubectl label pods app1 environment=staging --overwrite
```

### Remove a Label

```bash
kubectl label pods app1 environment-
```

The `-` at the end removes the label.

### Add Annotations

```bash
kubectl annotate pods app2 description="This is a development pod"
kubectl annotate pods app2 owner="lab-user"
```

### View Annotations

```bash
kubectl describe pod app2 | grep -A 5 Annotations
```

### Remove Annotations

```bash
kubectl annotate pods app2 description-
```

---

## Part 8: Debugging Commands

### View Pod Logs

First, let's create a pod that produces logs:

```bash
kubectl run logtest --image=busybox --command -- sh -c "while true; do echo 'Hello from logtest - '$(date); sleep 5; done"
```

Wait for the pod to start:

```bash
kubectl get pods logtest --watch
```

Press `Ctrl+C` when status is `Running`.

### View Logs

```bash
kubectl logs logtest
```

### Stream Logs in Real-Time

```bash
kubectl logs logtest -f
```

Press `Ctrl+C` to stop.

### View Logs from a Specific Container

For pods with multiple containers:

```bash
kubectl logs <pod-name> -c <container-name>
```

### View Previous Container Logs

If a container has restarted:

```bash
kubectl logs logtest --previous
```

### Execute Commands in a Container

```bash
# Run a single command
kubectl exec logtest -- hostname

# Run interactive shell
kubectl exec -it logtest -- sh
```

Inside the container:

```sh
# Check environment
env

# Check network
ip addr

# Check processes
ps aux

# Exit
exit
```

### Copy Files To/From Containers

Create a test file in the container:

```bash
kubectl exec logtest -- sh -c "echo 'Hello from container' > /tmp/test.txt"
```

Copy file from container to local machine:

```bash
kubectl cp logtest:/tmp/test.txt ./test-from-container.txt
cat ./test-from-container.txt
```

Copy file from local machine to container:

```bash
echo "Hello from host" > ./test-from-host.txt
kubectl cp ./test-from-host.txt logtest:/tmp/test-from-host.txt
kubectl exec logtest -- cat /tmp/test-from-host.txt
```

### Port Forwarding

Create an nginx pod for port forwarding:

```bash
kubectl run nginx-pf --image=nginx:alpine
kubectl wait --for=condition=Ready pod/nginx-pf
```

Forward local port 8080 to container port 80:

```bash
kubectl port-forward nginx-pf 8080:80 &
```

Test the connection:

```bash
curl localhost:8080
```

Stop port forwarding:

```bash
# Find and kill the background process
pkill -f "port-forward nginx-pf"
```

### View Events

```bash
# View events in current namespace
kubectl get events

# View events sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events --watch
```

### Attach to a Running Container

```bash
kubectl attach logtest
```

Press `Ctrl+C` to detach.

---

## Part 9: Resource Monitoring

The `top` command shows resource usage (requires metrics-server).

### Check if Metrics Server is Available

```bash
kubectl top nodes
```

If this fails with an error like `error: Metrics API not available`, you need to install metrics-server.

### Installing Metrics Server for KIND Clusters

KIND clusters require a modified metrics-server configuration because the kubelet uses self-signed certificates. Follow these steps:

**Step 1: Ensure no previous metrics-server exists**

```bash
# Check if metrics-server is already installed
kubectl get deployment metrics-server -n kube-system 2>/dev/null && echo "Metrics server exists - cleaning up first"

# If it exists, delete it completely
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null || true

# Force delete any remaining pods
kubectl delete pods -n kube-system -l k8s-app=metrics-server --force --grace-period=0 2>/dev/null || true

# Verify clean state
kubectl get all -n kube-system | grep metrics
```

**Step 2: Install metrics-server**

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Step 3: Patch for KIND compatibility**

Add the `--kubelet-insecure-tls` argument to skip certificate verification:

```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

**Step 4: Wait for rollout to complete**

```bash
kubectl rollout status deployment/metrics-server -n kube-system
```

**Step 5: Verify the pod is running**

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

You should see `1/1 Running`.

**Step 6: Wait for metrics collection and test**

Metrics-server needs 30-60 seconds to collect data:

```bash
sleep 60
kubectl top nodes
```

### Quick Installation (Single Command Block)

Copy and paste this entire block for a clean installation:

```bash
# Clean any existing installation
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null || true
kubectl delete pods -n kube-system -l k8s-app=metrics-server --force --grace-period=0 2>/dev/null || true
sleep 5

# Install and patch
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for rollout
kubectl rollout status deployment/metrics-server -n kube-system

# Verify
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Wait and test
echo "Waiting 60 seconds for metrics collection..."
sleep 60
kubectl top nodes
```

### Troubleshooting Metrics Server

If `kubectl top nodes` still doesn't work:

```bash
# Check if metrics-server pod is running
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check metrics-server logs for errors
kubectl logs -n kube-system deployment/metrics-server

# Check if the APIService is available
kubectl get apiservice v1beta1.metrics.k8s.io
```

Common issues:

| Issue | Symptom | Solution |
|-------|---------|----------|
| Pod not ready | `0/1 Ready` for 1-2 minutes | Wait for metrics collection |
| Certificate errors | `x509: cannot validate certificate` in logs | `--kubelet-insecure-tls` flag missing |
| Unknown flag panic | `panic: unknown flag` in logs | Delete completely and reinstall |
| Readiness probe failed | `HTTP probe failed with statuscode: 500` | `--kubelet-insecure-tls` flag missing |
| Rollout stuck | Old replicas pending termination | Force delete pods (see below) |

### Fixing a Stuck or Broken Installation

If metrics-server is stuck, in CrashLoopBackOff, or showing errors:

```bash
# Force delete all metrics-server resources
kubectl delete pods -n kube-system -l k8s-app=metrics-server --force --grace-period=0
kubectl delete replicaset -n kube-system -l k8s-app=metrics-server
kubectl delete deployment metrics-server -n kube-system --force --grace-period=0

# Wait for cleanup
sleep 5

# Verify clean
kubectl get all -n kube-system | grep metrics

# Reinstall fresh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for rollout
kubectl rollout status deployment/metrics-server -n kube-system

# Test after 60 seconds
sleep 60
kubectl top nodes
```

### View Node Resource Usage

```bash
kubectl top nodes
```

Output shows:

```
NAME                         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
kind-cluster-control-plane   150m         7%     650Mi           8%
kind-cluster-worker          50m          2%     300Mi           4%
```

### View Pod Resource Usage

```bash
kubectl top pods

# Across all namespaces
kubectl top pods -A

# Sorted by CPU
kubectl top pods --sort-by=cpu

# Sorted by memory
kubectl top pods --sort-by=memory
```

---

## Part 10: Cluster Management (Optional Advanced)

These commands are used for node maintenance operations.

### View Node Status

```bash
kubectl get nodes
kubectl describe node kind-cluster-worker
```

### Cordon a Node

Cordoning prevents new pods from being scheduled on the node:

```bash
kubectl cordon kind-cluster-worker
```

Verify:

```bash
kubectl get nodes
```

The worker node shows `SchedulingDisabled`.

### Try Scheduling a New Pod

```bash
kubectl run test-scheduling --image=alpine --command -- sleep 3600
kubectl get pod test-scheduling -o wide
```

The pod will be scheduled on the control-plane node (the only one available).

### Uncordon the Node

```bash
kubectl uncordon kind-cluster-worker
kubectl get nodes
```

### Drain a Node (Move All Pods Away)

**Warning**: Be careful with drain in production!

```bash
# Dry run first
kubectl drain kind-cluster-worker --ignore-daemonsets --dry-run=client

# Actually drain (don't do this unless you understand the impact)
# kubectl drain kind-cluster-worker --ignore-daemonsets --delete-emptydir-data
```

For this lab, we won't actually drain the node to keep the cluster functional.

### Cleanup Test Pod

```bash
kubectl delete pod test-scheduling
```

---

## Part 11: Command Autocompletion

Enable tab completion for kubectl to increase productivity.

### Install bash-completion (if not installed)

```bash
sudo apt-get update && sudo apt-get install -y bash-completion
```

### Enable kubectl Autocompletion for Current Session

```bash
source <(kubectl completion bash)
```

### Enable Permanently

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

### Create a Shorter Alias

```bash
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

Now you can use `k` instead of `kubectl`:

```bash
k get pods
k get nodes
```

---

## Exercises

### Exercise 1: Namespace Management

Create a complete application environment:

1. Create a namespace called `webapp`
2. Create two pods in the namespace: `frontend` and `backend`
3. List all pods in the namespace
4. Add appropriate labels to each pod

```bash
# Create namespace
kubectl create namespace webapp

# Create pods
kubectl run frontend --image=nginx:alpine -n webapp
kubectl run backend --image=alpine -n webapp --command -- sleep 3600

# Wait for pods to be ready
kubectl get pods -n webapp --watch

# Add labels
kubectl label pods frontend -n webapp tier=frontend app=webapp
kubectl label pods backend -n webapp tier=backend app=webapp

# Verify
kubectl get pods -n webapp --show-labels
```

Cleanup:

```bash
kubectl delete namespace webapp
```

### Exercise 2: Creating and Managing Deployments

Create a deployment from YAML:

```bash
cd ~/k8s-lab

cat > web-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f web-deployment.yaml
```

Verify:

```bash
kubectl get deployments
kubectl get pods -l app=web
kubectl describe deployment web-deployment
```

Scale the deployment:

```bash
kubectl scale deployment web-deployment --replicas=5
kubectl get pods -l app=web
```

Cleanup:

```bash
kubectl delete -f web-deployment.yaml
```

### Exercise 3: Debugging Practice

Create a problematic pod and debug it:

```bash
# Create a pod with a bad image
kubectl run broken --image=nginx:nonexistent

# Check the status
kubectl get pods broken

# Describe to see events
kubectl describe pod broken

# Check events
kubectl get events --field-selector involvedObject.name=broken
```

The pod should show `ImagePullBackOff` or `ErrImagePull`.

Fix the pod:

```bash
kubectl delete pod broken
kubectl run broken --image=nginx:alpine
kubectl get pods broken
```

Cleanup:

```bash
kubectl delete pod broken
```

### Exercise 4: Port Forwarding Practice

1. Create an nginx deployment with a service
2. Use port-forward to access it locally

```bash
# Create deployment and service
kubectl create deployment web-svc --image=nginx:alpine
kubectl expose deployment web-svc --port=80

# Wait for pod to be ready
kubectl get pods -l app=web-svc --watch

# Port forward to the service
kubectl port-forward svc/web-svc 9090:80 &

# Test the connection
curl localhost:9090

# Stop port forwarding
pkill -f "port-forward svc/web-svc"
```

Cleanup:

```bash
kubectl delete deployment web-svc
kubectl delete service web-svc
```

---

## Optional Advanced Exercises

### Exercise 5: JSONPath Queries

Practice extracting data with JSONPath:

```bash
# Create some pods
kubectl run json1 --image=alpine --command -- sleep 3600
kubectl run json2 --image=alpine --command -- sleep 3600
kubectl run json3 --image=alpine --command -- sleep 3600

# Wait for pods to be ready
sleep 5

# Get all pod names
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Get pod names and their IPs (formatted)
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Get pods on a specific node
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -o jsonpath="{.items[?(@.spec.nodeName=='$NODE')].metadata.name}"
```

Cleanup:

```bash
kubectl delete pods json1 json2 json3
```

### Exercise 6: Working with Multiple Contexts

```bash
# Create namespaces for different environments
kubectl create namespace production
kubectl create namespace testing

# Create context for production
kubectl config set-context prod-ctx \
  --cluster=kind-kind-cluster \
  --user=kind-kind-cluster \
  --namespace=production

# Create context for testing
kubectl config set-context test-ctx \
  --cluster=kind-kind-cluster \
  --user=kind-kind-cluster \
  --namespace=testing

# List contexts
kubectl config get-contexts

# Create pods in each namespace using contexts
kubectl config use-context prod-ctx
kubectl run prod-app --image=alpine --command -- sleep 3600

kubectl config use-context test-ctx
kubectl run test-app --image=alpine --command -- sleep 3600

# Switch back to default context
kubectl config use-context kind-kind-cluster

# Verify pods in different namespaces
kubectl get pods -n production
kubectl get pods -n testing
```

Cleanup:

```bash
kubectl config use-context kind-kind-cluster
kubectl config delete-context prod-ctx
kubectl config delete-context test-ctx
kubectl delete namespace production testing
```

---

## Key Takeaways

- **Namespaces** organize objects into logical groups; use `-n` or `--namespace` to specify
- **Contexts** save namespace/cluster/user configurations for easy switching
- **kubectl get** is the primary command for viewing resources; use `-o yaml/json` for full details
- **kubectl apply** creates and updates resources from YAML files; it's idempotent
- **kubectl describe** provides detailed information and related events
- **Labels** are used for organization and selection; **annotations** store metadata
- **kubectl logs** and **kubectl exec** are essential debugging tools
- **Port-forward** enables local access to cluster services for debugging
- **Tab completion** significantly improves kubectl productivity

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl get <resource>` | List resources |
| `kubectl get <resource> -o wide` | List with more details |
| `kubectl get <resource> -o yaml` | Full YAML output |
| `kubectl describe <resource> <name>` | Detailed information |
| `kubectl explain <resource>` | API documentation |
| `kubectl apply -f <file>` | Create/update from file |
| `kubectl delete -f <file>` | Delete from file |
| `kubectl delete <resource> <name>` | Delete by name |
| `kubectl label <resource> <name> key=value` | Add label |
| `kubectl annotate <resource> <name> key=value` | Add annotation |
| `kubectl logs <pod>` | View container logs |
| `kubectl logs <pod> -f` | Stream logs |
| `kubectl exec -it <pod> -- <command>` | Execute command in container |
| `kubectl cp <pod>:<path> <local-path>` | Copy from container |
| `kubectl port-forward <pod> <local>:<container>` | Forward ports |
| `kubectl get events` | View cluster events |
| `kubectl top nodes` | Node resource usage |
| `kubectl top pods` | Pod resource usage |
| `kubectl cordon <node>` | Mark node unschedulable |
| `kubectl uncordon <node>` | Mark node schedulable |
| `kubectl drain <node>` | Evict pods from node |
| `kubectl config get-contexts` | List contexts |
| `kubectl config use-context <name>` | Switch context |
| `kubectl create namespace <name>` | Create namespace |

---

## Cleanup (End of Lab)

```bash
# Remove test pods
kubectl delete pods app1 app2 app3 logtest nginx-pf 2>/dev/null || true
kubectl delete pods lab-nginx 2>/dev/null || true

# Remove namespaces (this deletes all resources within them)
kubectl delete namespace dev 2>/dev/null || true
kubectl delete namespace webapp 2>/dev/null || true
kubectl delete namespace production 2>/dev/null || true
kubectl delete namespace testing 2>/dev/null || true

# Remove custom contexts
kubectl config delete-context dev-context 2>/dev/null || true
kubectl config delete-context prod-ctx 2>/dev/null || true
kubectl config delete-context test-ctx 2>/dev/null || true

# Remove lab files
rm -rf ~/k8s-lab

# Verify cleanup
kubectl get pods
kubectl get namespaces
kubectl config get-contexts
```

---

## Troubleshooting Common Issues

### kubectl command not found

```bash
# Check if kubectl is in PATH
which kubectl

# If not, add to PATH
export PATH=$PATH:/usr/local/bin
```

### Cannot connect to cluster

```bash
# Check if KIND cluster is running
docker ps | grep kind

# If not running, check if it exists
kind get clusters

# Recreate cluster if needed
kind delete cluster --name kind-cluster
sudo ./install_kind.sh
```

### Permission denied errors

```bash
# Ensure user is in docker group
groups | grep docker

# If not, add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Pods stuck in Pending state

```bash
# Check events for the pod
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes

# Check if nodes are schedulable
kubectl get nodes
```

### Metrics not available

```bash
# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Check metrics-server logs
kubectl logs -n kube-system deployment/metrics-server
```

---

## Additional Resources

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [kubectl Reference Documentation](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)
- [KIND Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

