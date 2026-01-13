# Kubernetes User Management – Simple Lab (KIND Cluster)

A straightforward lab for adding users and service accounts to your Kubernetes cluster.

---

## Prerequisites

- KIND cluster running
- kubectl configured

```bash
# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

---

## Part 1: Adding Service Accounts (For Applications/Scripts)

Service accounts are the simplest way to create identities in Kubernetes.

### Create a Service Account

```bash
# Create a service account named "developer"
kubectl create serviceaccount developer

# Verify it was created
kubectl get serviceaccount developer
```

### Give the Service Account Permissions

```bash
# Give "developer" edit access in the default namespace
kubectl create rolebinding developer-edit \
  --clusterrole=edit \
  --serviceaccount=default:developer

# Verify
kubectl get rolebinding developer-edit
```

### Test the Service Account

```bash
# Check what the service account can do
kubectl auth can-i create pods --as=system:serviceaccount:default:developer
kubectl auth can-i delete pods --as=system:serviceaccount:default:developer
kubectl auth can-i create namespaces --as=system:serviceaccount:default:developer
```

Expected output:
- create pods: `yes`
- delete pods: `yes`  
- create namespaces: `no` (edit role doesn't include cluster-level resources)

---

## Part 2: Create a Kubeconfig for a Service Account

This allows someone to use kubectl with the service account's permissions.

### Step 1: Get Cluster Information

```bash
# Get the cluster server URL
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "Cluster Server: $CLUSTER_SERVER"

# Get the cluster CA certificate
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > /tmp/ca.crt
```

### Step 2: Create a Token for the Service Account

```bash
# Create a long-lived token (Kubernetes 1.24+)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: developer-token
  annotations:
    kubernetes.io/service-account.name: developer
type: kubernetes.io/service-account-token
EOF

# Wait for token to be generated
sleep 3

# Get the token
SA_TOKEN=$(kubectl get secret developer-token -o jsonpath='{.data.token}' | base64 -d)
echo "Token generated successfully"
```

### Step 3: Create the Kubeconfig File

```bash
cat > developer-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
    server: $CLUSTER_SERVER
  name: kind-cluster
contexts:
- context:
    cluster: kind-cluster
    user: developer
    namespace: default
  name: developer-context
current-context: developer-context
users:
- name: developer
  user:
    token: $SA_TOKEN
EOF

echo "Kubeconfig created: developer-kubeconfig.yaml"
```

### Step 4: Test the Kubeconfig

```bash
# Test using the new kubeconfig
kubectl --kubeconfig=developer-kubeconfig.yaml get pods
kubectl --kubeconfig=developer-kubeconfig.yaml auth can-i create pods

# This should fail (no access to kube-system)
kubectl --kubeconfig=developer-kubeconfig.yaml get pods -n kube-system 2>&1 || echo "Access denied (expected)"
```

---

## Part 3: Quick User Setup Script

Use this script to quickly add new users:

```bash
cat > add-user.sh <<'SCRIPT'
#!/bin/bash

# Usage: ./add-user.sh <username> <role> [namespace]
# Roles: view, edit, admin, cluster-admin

USERNAME=$1
ROLE=${2:-view}
NAMESPACE=${3:-default}

if [ -z "$USERNAME" ]; then
    echo "Usage: ./add-user.sh <username> <role> [namespace]"
    echo "Roles: view, edit, admin, cluster-admin"
    exit 1
fi

echo "Creating user: $USERNAME with role: $ROLE in namespace: $NAMESPACE"

# Create service account
kubectl create serviceaccount $USERNAME -n $NAMESPACE 2>/dev/null || echo "ServiceAccount already exists"

# Create token secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${USERNAME}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: $USERNAME
type: kubernetes.io/service-account-token
EOF

sleep 2

# Create role binding
if [ "$ROLE" == "cluster-admin" ]; then
    kubectl create clusterrolebinding ${USERNAME}-binding \
        --clusterrole=cluster-admin \
        --serviceaccount=${NAMESPACE}:${USERNAME} 2>/dev/null || echo "ClusterRoleBinding already exists"
else
    kubectl create rolebinding ${USERNAME}-binding \
        --clusterrole=$ROLE \
        --serviceaccount=${NAMESPACE}:${USERNAME} \
        -n $NAMESPACE 2>/dev/null || echo "RoleBinding already exists"
fi

# Get cluster info
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
SA_TOKEN=$(kubectl get secret ${USERNAME}-token -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d)

# Generate kubeconfig
cat > ${USERNAME}-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_DATA
    server: $CLUSTER_SERVER
  name: kind-cluster
contexts:
- context:
    cluster: kind-cluster
    user: $USERNAME
    namespace: $NAMESPACE
  name: ${USERNAME}-context
current-context: ${USERNAME}-context
users:
- name: $USERNAME
  user:
    token: $SA_TOKEN
EOF

echo ""
echo "✅ User '$USERNAME' created successfully!"
echo "   Kubeconfig: ${USERNAME}-kubeconfig.yaml"
echo ""
echo "Test with: kubectl --kubeconfig=${USERNAME}-kubeconfig.yaml get pods"
SCRIPT

chmod +x add-user.sh
```

### Use the Script

```bash
# Create a viewer user (read-only)
./add-user.sh alice view

# Create an editor user (read/write in namespace)
./add-user.sh bob edit

# Create an admin user (full namespace access)
./add-user.sh charlie admin

# Create a cluster admin (full cluster access - use carefully!)
./add-user.sh superadmin cluster-admin
```

### Test Each User

```bash
echo "=== Testing alice (view) ==="
kubectl --kubeconfig=alice-kubeconfig.yaml auth can-i get pods
kubectl --kubeconfig=alice-kubeconfig.yaml auth can-i create pods

echo ""
echo "=== Testing bob (edit) ==="
kubectl --kubeconfig=bob-kubeconfig.yaml auth can-i get pods
kubectl --kubeconfig=bob-kubeconfig.yaml auth can-i create pods
kubectl --kubeconfig=bob-kubeconfig.yaml auth can-i create roles

echo ""
echo "=== Testing charlie (admin) ==="
kubectl --kubeconfig=charlie-kubeconfig.yaml auth can-i get pods
kubectl --kubeconfig=charlie-kubeconfig.yaml auth can-i create pods
kubectl --kubeconfig=charlie-kubeconfig.yaml auth can-i create roles
```

---

## Part 4: Common User Roles

| Role | Access Level | Use For |
|------|--------------|---------|
| `view` | Read-only | Observers, auditors, new team members |
| `edit` | Read/Write resources | Developers who need to deploy |
| `admin` | Full namespace control | Team leads, namespace owners |
| `cluster-admin` | Full cluster control | Platform admins only! |

### Create Custom Limited Role

```bash
# Create a role that can only view and restart pods
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-restarter
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments/scale"]
  verbs: ["patch"]
EOF

# Bind it to a user
kubectl create serviceaccount ops-user
kubectl create rolebinding ops-user-binding \
  --role=pod-restarter \
  --serviceaccount=default:ops-user

# Test
kubectl auth can-i delete pods --as=system:serviceaccount:default:ops-user
kubectl auth can-i create pods --as=system:serviceaccount:default:ops-user
```

---

## Part 5: List All Users and Permissions

### See All Service Accounts

```bash
# List all service accounts
kubectl get serviceaccounts --all-namespaces

# List service accounts in default namespace
kubectl get sa
```

### See All Role Bindings

```bash
# List all rolebindings in default namespace
kubectl get rolebindings

# List all clusterrolebindings
kubectl get clusterrolebindings | grep -v "system:"
```

### Check Specific User's Permissions

```bash
# List what a service account can do
kubectl auth can-i --list --as=system:serviceaccount:default:developer
```

---

## Cleanup

```bash
# Delete service accounts and bindings created in this lab
kubectl delete sa developer alice bob charlie superadmin ops-user 2>/dev/null
kubectl delete secret developer-token alice-token bob-token charlie-token superadmin-token 2>/dev/null
kubectl delete rolebinding developer-edit alice-binding bob-binding charlie-binding ops-user-binding 2>/dev/null
kubectl delete clusterrolebinding superadmin-binding 2>/dev/null
kubectl delete role pod-restarter 2>/dev/null

# Delete generated files
rm -f developer-kubeconfig.yaml alice-kubeconfig.yaml bob-kubeconfig.yaml charlie-kubeconfig.yaml superadmin-kubeconfig.yaml
rm -f add-user.sh /tmp/ca.crt

echo "Cleanup complete!"
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Create service account | `kubectl create sa <name>` |
| Give view access | `kubectl create rolebinding <name>-view --clusterrole=view --serviceaccount=default:<name>` |
| Give edit access | `kubectl create rolebinding <name>-edit --clusterrole=edit --serviceaccount=default:<name>` |
| Give admin access | `kubectl create rolebinding <name>-admin --clusterrole=admin --serviceaccount=default:<name>` |
| Check permissions | `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:default:<name>` |
| List permissions | `kubectl auth can-i --list --as=system:serviceaccount:default:<name>` |
