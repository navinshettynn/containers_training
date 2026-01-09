# Kubernetes Role-Based Access Control (RBAC) – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services, Secrets & ConfigMaps)

> **Important**: This lab assumes familiarity with kubectl commands, Pod concepts, and basic Kubernetes resources. If you haven't completed the previous labs, do those first.

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

---

## Learning Objectives

### Core RBAC Concepts

- Understand **authentication** vs **authorization** in Kubernetes
- Learn what **Role-Based Access Control (RBAC)** is and why it's important
- Understand the four RBAC API objects: **Role**, **ClusterRole**, **RoleBinding**, **ClusterRoleBinding**
- Create and manage **Service Accounts**

### Roles and Bindings

- Create **Roles** with specific permissions
- Create **RoleBindings** to assign roles to users/groups/service accounts
- Understand the difference between **namespaced** and **cluster-scoped** resources
- Use **ClusterRoles** and **ClusterRoleBindings** for cluster-wide access

### Practical Skills

- Test permissions using `kubectl auth can-i`
- Use **built-in roles** (admin, edit, view, cluster-admin)
- Configure **least privilege** access for applications
- Troubleshoot RBAC permission issues

### Intermediate Objectives (Optional)

- Aggregate **ClusterRoles** for modular permission management
- Use **Groups** for scalable access control
- Implement **namespace isolation** with RBAC

---

## Part 1: Understanding RBAC Concepts

### What is RBAC?

Role-Based Access Control (RBAC) is a method of regulating access to resources based on the roles of individual users or service accounts.

| Feature | Description |
|---------|-------------|
| **Authentication** | Verifies WHO you are (identity) |
| **Authorization** | Determines WHAT you can do (permissions) |
| **Role** | A set of permissions (rules) |
| **Binding** | Links roles to identities |

### Authentication vs Authorization

| Phase | Question | Example |
|-------|----------|---------|
| **Authentication** | "Who are you?" | User alice, ServiceAccount default |
| **Authorization** | "What can you do?" | Create Pods, Delete Services |

### RBAC API Objects

| Object | Scope | Purpose |
|--------|-------|---------|
| **Role** | Namespace | Define permissions within a namespace |
| **ClusterRole** | Cluster | Define permissions cluster-wide |
| **RoleBinding** | Namespace | Bind Role/ClusterRole to subjects in a namespace |
| **ClusterRoleBinding** | Cluster | Bind ClusterRole to subjects cluster-wide |

### Why RBAC Matters

| Scenario | Without RBAC | With RBAC |
|----------|--------------|-----------|
| Developer access | Full cluster access | Only their namespace |
| Production protection | Anyone can delete | Only admins can modify |
| Audit & Compliance | No access control | Clear permission boundaries |
| Automation | Shared credentials | Dedicated service accounts |

> **Security Note**: RBAC is essential but not sufficient for complete security. For hostile multi-tenant environments, you also need Pod security, network policies, and potentially hypervisor-isolated containers.

---

## Part 2: Identities in Kubernetes

### Create a Lab Directory

```bash
mkdir -p ~/rbac-lab
cd ~/rbac-lab
```

### Understanding Identity Types

| Identity Type | Description | Example |
|---------------|-------------|---------|
| **User** | Human users (external to K8s) | alice, bob@company.com |
| **Group** | Collection of users | developers, admins |
| **ServiceAccount** | Machine identity (internal to K8s) | default, my-app-sa |

### View Current Identity

```bash
# See your current context and user
kubectl config current-context
kubectl config view --minify -o jsonpath='{.contexts[0].context.user}'
```

### Special Identities

| Identity | Description |
|----------|-------------|
| `system:unauthenticated` | Requests without valid credentials |
| `system:authenticated` | All authenticated users |
| `system:serviceaccounts` | All service accounts |
| `system:serviceaccounts:<namespace>` | Service accounts in a namespace |
| `system:masters` | Super-admin group (bypass RBAC) |

---

## Part 3: Service Accounts

Service accounts provide identity for Pods and other workloads running in the cluster.

### View Default Service Account

Every namespace has a default service account:

```bash
# View service accounts in default namespace
kubectl get serviceaccounts

# Describe the default service account
kubectl describe serviceaccount default
```

### Create a Custom Service Account

```bash
cat > custom-sa.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  labels:
    app: my-app
EOF

kubectl apply -f custom-sa.yaml
kubectl get serviceaccount my-app-sa
```

### Create Service Account Imperatively

```bash
kubectl create serviceaccount demo-sa
kubectl get sa demo-sa -o yaml
```

### Use Service Account in a Pod

```bash
cat > pod-with-sa.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-sa
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== ServiceAccount Info ==="
      echo "Namespace: $(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
      echo "ServiceAccount: my-app-sa"
      echo "Token exists: $(test -f /var/run/secrets/kubernetes.io/serviceaccount/token && echo 'yes' || echo 'no')"
      echo "CA cert exists: $(test -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt && echo 'yes' || echo 'no')"
      sleep 3600
  restartPolicy: Never
EOF

kubectl apply -f pod-with-sa.yaml
sleep 5
kubectl logs pod-with-sa
```

Expected output:

```
=== ServiceAccount Info ===
Namespace: default
ServiceAccount: my-app-sa
Token exists: yes
CA cert exists: yes
```

### View Service Account Token (Mounted in Pod)

```bash
# See the mounted service account credentials
kubectl exec pod-with-sa -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# View the namespace
kubectl exec pod-with-sa -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace

# View the token (truncated for display)
kubectl exec pod-with-sa -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50
echo "..."
```

### Cleanup Part 3

```bash
kubectl delete pod pod-with-sa
kubectl delete sa my-app-sa demo-sa
rm -f custom-sa.yaml pod-with-sa.yaml
```

---

## Part 4: Creating Roles

Roles define WHAT actions can be performed on WHICH resources.

### Role Structure

A Role consists of **rules**, each with:

| Field | Description | Example |
|-------|-------------|---------|
| `apiGroups` | API group containing the resource | `""` (core), `apps`, `batch` |
| `resources` | Resource types | `pods`, `services`, `deployments` |
| `verbs` | Actions allowed | `get`, `list`, `create`, `delete` |
| `resourceNames` | Specific resource names (optional) | `my-pod`, `my-config` |

### Common Verbs

| Verb | HTTP Method | Description |
|------|-------------|-------------|
| `create` | POST | Create a new resource |
| `get` | GET | Retrieve a single resource |
| `list` | GET | List all resources of a type |
| `watch` | GET (streaming) | Watch for changes |
| `update` | PUT | Replace entire resource |
| `patch` | PATCH | Modify part of a resource |
| `delete` | DELETE | Delete a resource |
| `deletecollection` | DELETE | Delete multiple resources |

### Create a Read-Only Role

```bash
cat > role-readonly.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]           # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

kubectl apply -f role-readonly.yaml
kubectl describe role pod-reader
```

### Create a Role with Multiple Rules

```bash
cat > role-developer.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: developer
rules:
# Full access to Pods
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Read-only access to Services
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch"]
# Full access to Deployments
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Read-only access to ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
EOF

kubectl apply -f role-developer.yaml
kubectl describe role developer
```

### Create Role for Specific Resources

```bash
cat > role-specific.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: configmap-editor
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config", "db-config"]  # Only these specific ConfigMaps
  verbs: ["get", "update", "patch"]
EOF

kubectl apply -f role-specific.yaml
kubectl describe role configmap-editor
```

### Common API Groups

| API Group | Resources | Description |
|-----------|-----------|-------------|
| `""` (core) | pods, services, configmaps, secrets, namespaces | Core resources |
| `apps` | deployments, replicasets, statefulsets, daemonsets | Workload controllers |
| `batch` | jobs, cronjobs | Batch workloads |
| `networking.k8s.io` | ingresses, networkpolicies | Networking |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles | RBAC itself |

### Cleanup Part 4

```bash
kubectl delete role pod-reader developer configmap-editor
rm -f role-readonly.yaml role-developer.yaml role-specific.yaml
```

---

## Part 5: Creating Role Bindings

RoleBindings connect Roles to Subjects (users, groups, or service accounts).

### RoleBinding Structure

| Field | Description |
|-------|-------------|
| `subjects` | WHO gets the permissions (users, groups, service accounts) |
| `roleRef` | WHICH Role or ClusterRole to bind |

### Subject Types

| Kind | Description | Example |
|------|-------------|---------|
| `User` | Individual user account | `alice` |
| `Group` | Group of users | `developers` |
| `ServiceAccount` | Kubernetes service account | `default`, `my-app-sa` |

### Create Role and RoleBinding Together

```bash
cat > rbac-demo.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: demo-app-pod-manager
  namespace: default
subjects:
- kind: ServiceAccount
  name: demo-app
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-manager
EOF

kubectl apply -f rbac-demo.yaml
```

### View the RoleBinding

```bash
kubectl get rolebinding demo-app-pod-manager
kubectl describe rolebinding demo-app-pod-manager
```

### Bind to Multiple Subjects

```bash
cat > multi-subject-binding.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-pod-readers
  namespace: default
subjects:
# Service Account
- kind: ServiceAccount
  name: demo-app
  namespace: default
# User (would be authenticated by external provider)
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
# Group
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-manager
EOF

kubectl apply -f multi-subject-binding.yaml
kubectl describe rolebinding team-pod-readers
```

### Test Permissions

```bash
# Test if the demo-app service account can get pods
kubectl auth can-i get pods --as=system:serviceaccount:default:demo-app

# Test if it can delete pods
kubectl auth can-i delete pods --as=system:serviceaccount:default:demo-app

# Test if it can create deployments (should be no)
kubectl auth can-i create deployments --as=system:serviceaccount:default:demo-app

# Test pod logs (subresource)
kubectl auth can-i get pods --subresource=log --as=system:serviceaccount:default:demo-app
```

### Cleanup Part 5

```bash
kubectl delete -f rbac-demo.yaml
kubectl delete rolebinding team-pod-readers
rm -f rbac-demo.yaml multi-subject-binding.yaml
```

---

## Part 6: ClusterRoles and ClusterRoleBindings

ClusterRoles and ClusterRoleBindings work at the cluster level, not namespace level.

### When to Use ClusterRole vs Role

| Use Case | Resource Type |
|----------|---------------|
| Namespace-scoped permissions | Role + RoleBinding |
| Cluster-wide permissions | ClusterRole + ClusterRoleBinding |
| Non-namespaced resources (nodes, PVs) | ClusterRole + ClusterRoleBinding |
| Reusable role across namespaces | ClusterRole + RoleBinding |

### Create a ClusterRole

```bash
cat > clusterrole-node-reader.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
# Nodes are cluster-scoped (not namespaced)
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
# Node metrics
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes"]
  verbs: ["get", "list"]
EOF

kubectl apply -f clusterrole-node-reader.yaml
kubectl describe clusterrole node-reader
```

### Create a ClusterRoleBinding

```bash
cat > clusterrolebinding-demo.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-viewer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer-nodes
subjects:
- kind: ServiceAccount
  name: cluster-viewer
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: node-reader
EOF

kubectl apply -f clusterrolebinding-demo.yaml
```

### Test Cluster-Wide Permissions

```bash
# Test node access
kubectl auth can-i get nodes --as=system:serviceaccount:default:cluster-viewer
kubectl auth can-i list nodes --as=system:serviceaccount:default:cluster-viewer

# Test other cluster resources (should be no)
kubectl auth can-i get persistentvolumes --as=system:serviceaccount:default:cluster-viewer
```

### Using ClusterRole with RoleBinding (Namespace-Scoped)

A ClusterRole can be bound to a namespace using RoleBinding:

```bash
cat > clusterrole-reuse.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-with-secrets
  namespace: default
---
# Use RoleBinding (not ClusterRoleBinding) to limit to namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-reader
  namespace: default  # Only grants access in default namespace
subjects:
- kind: ServiceAccount
  name: app-with-secrets
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole  # Reference ClusterRole, not Role
  name: secret-reader
EOF

kubectl apply -f clusterrole-reuse.yaml
```

### Test Namespace-Scoped ClusterRole

```bash
# Can read secrets in default namespace
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-with-secrets -n default

# Cannot read secrets in kube-system namespace
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-with-secrets -n kube-system
```

### Cleanup Part 6

```bash
kubectl delete clusterrole node-reader secret-reader
kubectl delete clusterrolebinding cluster-viewer-nodes
kubectl delete sa cluster-viewer app-with-secrets
kubectl delete rolebinding app-secret-reader
rm -f clusterrole-node-reader.yaml clusterrolebinding-demo.yaml clusterrole-reuse.yaml
```

---

## Part 7: Built-in Roles

Kubernetes provides several built-in ClusterRoles for common use cases.

### View Built-in ClusterRoles

```bash
# List all ClusterRoles
kubectl get clusterroles

# Filter to see built-in user-facing roles
kubectl get clusterroles | grep -E "^admin|^edit|^view|^cluster-admin"
```

### Built-in User-Facing Roles

| Role | Scope | Permissions |
|------|-------|-------------|
| `cluster-admin` | Cluster | Full control over everything |
| `admin` | Namespace | Full control within a namespace |
| `edit` | Namespace | Read/write access to most resources |
| `view` | Namespace | Read-only access to most resources |

### Examine Built-in Roles

```bash
# View the 'view' ClusterRole
kubectl describe clusterrole view

# View the 'edit' ClusterRole  
kubectl describe clusterrole edit

# View the 'admin' ClusterRole
kubectl describe clusterrole admin
```

### Compare Built-in Roles

```bash
echo "=== VIEW Role - Key Permissions ==="
kubectl get clusterrole view -o yaml | grep -A 100 "rules:" | head -40

echo ""
echo "=== EDIT Role - Key Permissions ==="
kubectl get clusterrole edit -o yaml | grep -A 100 "rules:" | head -40
```

### Use Built-in Roles

```bash
cat > builtin-role-demo.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: team-alpha
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-alpha-viewer
  namespace: team-alpha
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-alpha-editor
  namespace: team-alpha
---
# Grant view access
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewer-binding
  namespace: team-alpha
subjects:
- kind: ServiceAccount
  name: team-alpha-viewer
  namespace: team-alpha
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
---
# Grant edit access
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: editor-binding
  namespace: team-alpha
subjects:
- kind: ServiceAccount
  name: team-alpha-editor
  namespace: team-alpha
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
EOF

kubectl apply -f builtin-role-demo.yaml
```

### Test Built-in Role Permissions

```bash
echo "=== Testing VIEWER permissions ==="
# Viewer can read
kubectl auth can-i get pods --as=system:serviceaccount:team-alpha:team-alpha-viewer -n team-alpha
kubectl auth can-i list deployments --as=system:serviceaccount:team-alpha:team-alpha-viewer -n team-alpha

# Viewer cannot write
kubectl auth can-i create pods --as=system:serviceaccount:team-alpha:team-alpha-viewer -n team-alpha
kubectl auth can-i delete services --as=system:serviceaccount:team-alpha:team-alpha-viewer -n team-alpha

echo ""
echo "=== Testing EDITOR permissions ==="
# Editor can read and write
kubectl auth can-i get pods --as=system:serviceaccount:team-alpha:team-alpha-editor -n team-alpha
kubectl auth can-i create pods --as=system:serviceaccount:team-alpha:team-alpha-editor -n team-alpha
kubectl auth can-i delete services --as=system:serviceaccount:team-alpha:team-alpha-editor -n team-alpha

# Editor cannot modify roles
kubectl auth can-i create roles --as=system:serviceaccount:team-alpha:team-alpha-editor -n team-alpha
```

### Cleanup Part 7

```bash
kubectl delete namespace team-alpha
rm -f builtin-role-demo.yaml
```

---

## Part 8: Testing and Debugging RBAC

### Using kubectl auth can-i

The `can-i` command is essential for testing RBAC configuration.

```bash
# Basic syntax
kubectl auth can-i VERB RESOURCE [--namespace=NAMESPACE]

# Test as yourself
kubectl auth can-i create pods

# Test as a service account
kubectl auth can-i create pods --as=system:serviceaccount:default:my-sa

# Test as a user
kubectl auth can-i create pods --as=alice

# Test in a specific namespace
kubectl auth can-i create pods -n kube-system

# Test subresources
kubectl auth can-i get pods --subresource=log

# List all permissions (for yourself)
kubectl auth can-i --list

# List all permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa
```

### Create Test Environment

```bash
cat > rbac-test-env.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-test
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: limited-sa
  namespace: rbac-test
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: limited-role
  namespace: rbac-test
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: limited-binding
  namespace: rbac-test
subjects:
- kind: ServiceAccount
  name: limited-sa
  namespace: rbac-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: limited-role
EOF

kubectl apply -f rbac-test-env.yaml
```

### Comprehensive Permission Testing

```bash
echo "=== Testing limited-sa permissions in rbac-test namespace ==="
echo ""

# What can this service account do?
echo "All permissions for limited-sa:"
kubectl auth can-i --list --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test

echo ""
echo "=== Specific Tests ==="

# Pods
echo "get pods: $(kubectl auth can-i get pods --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"
echo "list pods: $(kubectl auth can-i list pods --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"
echo "create pods: $(kubectl auth can-i create pods --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"
echo "delete pods: $(kubectl auth can-i delete pods --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"

echo ""
# ConfigMaps
echo "get configmaps: $(kubectl auth can-i get configmaps --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"
echo "list configmaps: $(kubectl auth can-i list configmaps --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"

echo ""
# Secrets (should all be no)
echo "get secrets: $(kubectl auth can-i get secrets --as=system:serviceaccount:rbac-test:limited-sa -n rbac-test)"

echo ""
# Different namespace (should all be no)
echo "get pods in default: $(kubectl auth can-i get pods --as=system:serviceaccount:rbac-test:limited-sa -n default)"
```

### Debug Permission Denied Errors

When you get a permission denied error, check:

```bash
# 1. Check if the role exists
kubectl get role limited-role -n rbac-test

# 2. Check if the rolebinding exists
kubectl get rolebinding limited-binding -n rbac-test

# 3. Check the role's rules
kubectl describe role limited-role -n rbac-test

# 4. Check the rolebinding's subjects
kubectl describe rolebinding limited-binding -n rbac-test

# 5. Verify the service account exists
kubectl get sa limited-sa -n rbac-test
```

### Cleanup Part 8

```bash
kubectl delete namespace rbac-test
rm -f rbac-test-env.yaml
```

---

## Part 9: RBAC for Applications

### Practical Example: Application with Specific Permissions

```bash
cat > app-rbac.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: myapp
---
# Role for the application
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapp-role
  namespace: myapp
rules:
# Read own ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
# Read own Secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
# Read pod info (for health checks, debugging)
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
# Read pod logs
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-rolebinding
  namespace: myapp
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: myapp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: myapp-role
---
# Application deployment using the service account
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: app
        image: bitnami/kubectl:latest
        command: ["sleep", "3600"]
---
# ConfigMap for the application
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
EOF

kubectl apply -f app-rbac.yaml
kubectl wait --for=condition=Available deployment/myapp -n myapp --timeout=60s
```

### Test Application Permissions from Inside the Pod

```bash
# Get pod name
POD=$(kubectl get pod -n myapp -l app=myapp -o jsonpath='{.items[0].metadata.name}')

# Test reading ConfigMaps (should work)
echo "=== Reading ConfigMaps (should work) ==="
kubectl exec -n myapp $POD -- kubectl get configmaps -n myapp

# Test reading pods (should work)
echo ""
echo "=== Reading Pods (should work) ==="
kubectl exec -n myapp $POD -- kubectl get pods -n myapp

# Test creating pods (should fail)
echo ""
echo "=== Creating Pods (should fail) ==="
kubectl exec -n myapp $POD -- kubectl run test-pod --image=nginx -n myapp 2>&1 || echo "(Expected failure)"

# Test accessing other namespaces (should fail)
echo ""
echo "=== Reading Pods in default namespace (should fail) ==="
kubectl exec -n myapp $POD -- kubectl get pods -n default 2>&1 || echo "(Expected failure)"
```

### Cleanup Part 9

```bash
kubectl delete namespace myapp
rm -f app-rbac.yaml
```

---

## Scenario-Based Exercises: SecureBank Multi-Team Access Control

You've been hired as the Security Engineer at **SecureBank**, a fintech startup deploying their banking platform on Kubernetes. Your mission: implement proper RBAC to ensure each team has appropriate access without compromising security.

> **Story Context**: SecureBank has three teams: Development, Operations, and Security. Each team needs different levels of access. The previous setup gave everyone cluster-admin access, which led to a developer accidentally deleting the production database!

```bash
# Setup: Create your workspace
cd ~/rbac-lab
```

---

### Exercise 1: The Chaos Before RBAC

**Scenario**: On your first day, you discover the terrifying truth - everyone has cluster-admin access!

**Your Task**: Understand why this is dangerous by demonstrating the risks.

#### Step 1: Simulate the Dangerous Setup

```bash
cat > dangerous-setup.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: securebank-prod
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-alice
  namespace: securebank-prod
---
# DANGEROUS: Giving developers cluster-admin!
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dangerous-dev-access
subjects:
- kind: ServiceAccount
  name: dev-alice
  namespace: securebank-prod
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
EOF

kubectl apply -f dangerous-setup.yaml
```

#### Step 2: See What a Developer Can Do (Scary!)

```bash
echo "😱 With cluster-admin, a developer can:"
echo ""

# Can delete any namespace
echo "Delete any namespace: $(kubectl auth can-i delete namespaces --as=system:serviceaccount:securebank-prod:dev-alice)"

# Can delete nodes
echo "Delete nodes: $(kubectl auth can-i delete nodes --as=system:serviceaccount:securebank-prod:dev-alice)"

# Can read all secrets (including other teams')
echo "Read all secrets: $(kubectl auth can-i get secrets --all-namespaces --as=system:serviceaccount:securebank-prod:dev-alice)"

# Can modify RBAC
echo "Modify RBAC: $(kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:securebank-prod:dev-alice)"

echo ""
echo "⚠️  This is why we need proper RBAC!"
```

#### Step 3: Clean Up the Dangerous Setup

```bash
kubectl delete clusterrolebinding dangerous-dev-access
kubectl delete namespace securebank-prod
rm dangerous-setup.yaml
echo "✓ Dangerous setup removed. Let's do this properly!"
```

---

### Exercise 2: Setting Up Namespace Isolation

**Scenario**: The CTO mandates: "Each team gets their own namespace. Nobody should access other teams' resources!"

**Your Task**: Create isolated namespaces for each team.

#### Step 1: Create Team Namespaces

```bash
cat > namespaces.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: securebank-dev
  labels:
    team: development
    environment: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: securebank-staging
  labels:
    team: operations
    environment: staging
---
apiVersion: v1
kind: Namespace
metadata:
  name: securebank-prod
  labels:
    team: operations
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: securebank-security
  labels:
    team: security
    environment: security
EOF

kubectl apply -f namespaces.yaml
kubectl get namespaces -l team
```

#### Step 2: Create Service Accounts for Team Members

```bash
cat > team-accounts.yaml <<'EOF'
# Development Team
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-alice
  namespace: securebank-dev
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-bob
  namespace: securebank-dev
---
# Operations Team
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-charlie
  namespace: securebank-staging
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-diana
  namespace: securebank-prod
---
# Security Team
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sec-eve
  namespace: securebank-security
EOF

kubectl apply -f team-accounts.yaml
```

---

### Exercise 3: Implementing Developer Access

**Scenario**: Developers need full access to the development namespace to build and test, but should only view production (no modifications allowed).

**Your Task**: Create RBAC rules for the development team.

#### Step 1: Create Developer Role

```bash
cat > dev-rbac.yaml <<'EOF'
# Full access role for development
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-full
  namespace: securebank-dev
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
---
# Read-only access for production (developers can view but not modify)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-readonly
  namespace: securebank-prod
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
# Note: No secrets access in production!
---
# Bind developers to their roles
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-full-access
  namespace: securebank-dev
subjects:
- kind: ServiceAccount
  name: dev-alice
  namespace: securebank-dev
- kind: ServiceAccount
  name: dev-bob
  namespace: securebank-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-full
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-prod-readonly
  namespace: securebank-prod
subjects:
- kind: ServiceAccount
  name: dev-alice
  namespace: securebank-dev
- kind: ServiceAccount
  name: dev-bob
  namespace: securebank-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-readonly
EOF

kubectl apply -f dev-rbac.yaml
```

#### Step 2: Test Developer Permissions

```bash
echo "╔════════════════════════════════════════════════╗"
echo "║      Testing Developer (Alice) Permissions      ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo "📁 In Development Namespace (securebank-dev):"
echo "   Create pods: $(kubectl auth can-i create pods --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-dev)"
echo "   Delete deployments: $(kubectl auth can-i delete deployments --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-dev)"
echo "   Read secrets: $(kubectl auth can-i get secrets --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-dev)"

echo ""
echo "🔒 In Production Namespace (securebank-prod):"
echo "   View pods: $(kubectl auth can-i get pods --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-prod)"
echo "   View pod logs: $(kubectl auth can-i get pods --subresource=log --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-prod)"
echo "   Create pods: $(kubectl auth can-i create pods --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-prod)"
echo "   Read secrets: $(kubectl auth can-i get secrets --as=system:serviceaccount:securebank-dev:dev-alice -n securebank-prod)"

echo ""
echo "✅ Developers have full dev access, read-only prod access, NO prod secrets!"
```

---

### Exercise 4: Implementing Operations Access

**Scenario**: Operations needs full access to staging and production for deployments and troubleshooting, but should not be able to modify RBAC settings.

**Your Task**: Create RBAC rules for the operations team.

#### Step 1: Create Operations Role

```bash
cat > ops-rbac.yaml <<'EOF'
# Operations full access (similar to admin, but no RBAC permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: operations-manager
rules:
# Full access to workloads
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/portforward", "services", "endpoints", "configmaps", "secrets", "persistentvolumeclaims"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
# Read-only cluster resources
- apiGroups: [""]
  resources: ["nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# NO rbac permissions!
---
# Staging access
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-staging-access
  namespace: securebank-staging
subjects:
- kind: ServiceAccount
  name: ops-charlie
  namespace: securebank-staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: operations-manager
---
# Production access
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-prod-access
  namespace: securebank-prod
subjects:
- kind: ServiceAccount
  name: ops-diana
  namespace: securebank-prod
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: operations-manager
EOF

kubectl apply -f ops-rbac.yaml
```

#### Step 2: Test Operations Permissions

```bash
echo "╔════════════════════════════════════════════════╗"
echo "║      Testing Operations (Diana) Permissions     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo "🚀 In Production Namespace:"
echo "   Create deployments: $(kubectl auth can-i create deployments --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-prod)"
echo "   Read secrets: $(kubectl auth can-i get secrets --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-prod)"
echo "   Exec into pods: $(kubectl auth can-i create pods --subresource=exec --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-prod)"

echo ""
echo "🛡️ RBAC Permissions (should all be NO):"
echo "   Create roles: $(kubectl auth can-i create roles --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-prod)"
echo "   Create rolebindings: $(kubectl auth can-i create rolebindings --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-prod)"
echo "   Modify clusterroles: $(kubectl auth can-i update clusterroles --as=system:serviceaccount:securebank-prod:ops-diana)"

echo ""
echo "🔒 Other Namespaces (should be NO):"
echo "   Access dev namespace: $(kubectl auth can-i get pods --as=system:serviceaccount:securebank-prod:ops-diana -n securebank-dev)"

echo ""
echo "✅ Operations has full workload access but cannot modify RBAC!"
```

---

### Exercise 5: Implementing Security Team Access

**Scenario**: The security team needs read-only access to EVERYTHING (for auditing) but cannot modify anything.

**Your Task**: Create RBAC rules for the security team with audit capabilities.

#### Step 1: Create Security Auditor Role

```bash
cat > security-rbac.yaml <<'EOF'
# Security Auditor - Can view everything, modify nothing
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
# Read all resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Read RBAC
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Read pod security
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies"]
  verbs: ["get", "list", "watch"]
# Read network policies
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-auditor-binding
subjects:
- kind: ServiceAccount
  name: sec-eve
  namespace: securebank-security
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: security-auditor
EOF

kubectl apply -f security-rbac.yaml
```

#### Step 2: Test Security Team Permissions

```bash
echo "╔════════════════════════════════════════════════╗"
echo "║      Testing Security (Eve) Permissions         ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo "👁️ Read Access (all namespaces):"
echo "   View pods (prod): $(kubectl auth can-i get pods --as=system:serviceaccount:securebank-security:sec-eve -n securebank-prod)"
echo "   View secrets (prod): $(kubectl auth can-i get secrets --as=system:serviceaccount:securebank-security:sec-eve -n securebank-prod)"
echo "   View pods (dev): $(kubectl auth can-i get pods --as=system:serviceaccount:securebank-security:sec-eve -n securebank-dev)"

echo ""
echo "📋 RBAC Audit Access:"
echo "   View roles: $(kubectl auth can-i list roles --as=system:serviceaccount:securebank-security:sec-eve --all-namespaces)"
echo "   View rolebindings: $(kubectl auth can-i list rolebindings --as=system:serviceaccount:securebank-security:sec-eve --all-namespaces)"
echo "   View clusterroles: $(kubectl auth can-i list clusterroles --as=system:serviceaccount:securebank-security:sec-eve)"

echo ""
echo "✋ Write Access (should all be NO):"
echo "   Create pods: $(kubectl auth can-i create pods --as=system:serviceaccount:securebank-security:sec-eve -n securebank-prod)"
echo "   Delete secrets: $(kubectl auth can-i delete secrets --as=system:serviceaccount:securebank-security:sec-eve -n securebank-prod)"
echo "   Create roles: $(kubectl auth can-i create roles --as=system:serviceaccount:securebank-security:sec-eve -n securebank-prod)"

echo ""
echo "✅ Security can audit everything but modify nothing!"
```

---

### Exercise 6: Complete Access Matrix Verification

**Scenario**: The CISO wants a complete access matrix showing who can do what.

**Your Task**: Create a script to generate the access matrix.

#### Step 1: Generate Access Matrix

```bash
cat > check-access.sh <<'SCRIPT'
#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    SecureBank RBAC Access Matrix                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Define test subjects (using indexed arrays for consistent ordering)
SUBJECT_NAMES=("dev-alice" "ops-diana" "sec-eve")
SUBJECT_IDENTITIES=(
    "system:serviceaccount:securebank-dev:dev-alice"
    "system:serviceaccount:securebank-prod:ops-diana"
    "system:serviceaccount:securebank-security:sec-eve"
)

# Define namespaces
NAMESPACES=("securebank-dev" "securebank-prod")

# Define permissions to test (verb resource pairs)
VERBS=("get" "create" "delete" "get" "create" "create")
RESOURCES=("pods" "pods" "pods" "secrets" "deployments" "roles")

# Print header for each namespace
for ns in "${NAMESPACES[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Namespace: $ns"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Print column headers
    printf "%-15s" "Subject"
    for i in "${!VERBS[@]}"; do
        printf "| %-8s %-11s" "${VERBS[$i]}" "${RESOURCES[$i]}"
    done
    echo ""
    printf "%-15s" "───────────────"
    for i in "${!VERBS[@]}"; do
        printf "|─────────────────────"
    done
    echo ""
    
    # Print permissions for each subject
    for j in "${!SUBJECT_NAMES[@]}"; do
        subject_name="${SUBJECT_NAMES[$j]}"
        subject="${SUBJECT_IDENTITIES[$j]}"
        printf "%-15s" "$subject_name"
        
        for i in "${!VERBS[@]}"; do
            verb="${VERBS[$i]}"
            resource="${RESOURCES[$i]}"
            result=$(kubectl auth can-i $verb $resource --as=$subject -n $ns 2>/dev/null)
            if [ "$result" == "yes" ]; then
                printf "| %-19s" "✅ yes"
            else
                printf "| %-19s" "❌ no"
            fi
        done
        echo ""
    done
    echo ""
done

echo "Legend: ✅ = Allowed, ❌ = Denied"
SCRIPT

chmod +x check-access.sh
./check-access.sh
```

#### Step 2: Detailed Permission Report

```bash
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Detailed Permission Summary                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "👨‍💻 Developer (Alice):"
echo "   • Full access to securebank-dev"
echo "   • Read-only access to securebank-prod (no secrets)"
echo "   • No access to other namespaces"
echo ""

echo "👷 Operations (Diana):"
echo "   • Full workload access to securebank-staging and securebank-prod"
echo "   • Cannot modify RBAC settings"
echo "   • No access to development namespace"
echo ""

echo "🔐 Security (Eve):"
echo "   • Read-only access to ALL namespaces"
echo "   • Can audit RBAC configurations"
echo "   • Cannot modify anything"
echo ""

echo "✅ Least privilege principle implemented!"
```

---

### Final Exercise: Cleanup and Review

#### Step 1: Review All RBAC Resources

```bash
echo "📋 SecureBank RBAC Resources:"
echo ""
echo "Namespaces:"
kubectl get namespaces | grep securebank

echo ""
echo "Service Accounts:"
kubectl get sa -A | grep -E "dev-|ops-|sec-"

echo ""
echo "Roles:"
kubectl get roles -A | grep -E "securebank|developer|operations"

echo ""
echo "ClusterRoles:"
kubectl get clusterroles | grep -E "operations|security-auditor"

echo ""
echo "RoleBindings:"
kubectl get rolebindings -A | grep securebank

echo ""
echo "ClusterRoleBindings:"
kubectl get clusterrolebindings | grep -E "security-auditor"
```

#### Step 2: Clean Up All Resources

```bash
echo "🧹 Cleaning up SecureBank resources..."

# Delete namespaces (this will delete contained resources)
kubectl delete namespace securebank-dev securebank-staging securebank-prod securebank-security 2>/dev/null || true

# Delete cluster-scoped resources
kubectl delete clusterrole operations-manager security-auditor 2>/dev/null || true
kubectl delete clusterrolebinding security-auditor-binding 2>/dev/null || true

# Clean up files
rm -f namespaces.yaml team-accounts.yaml dev-rbac.yaml ops-rbac.yaml security-rbac.yaml check-access.sh

echo "✅ Cleanup complete!"
```

#### Step 3: Key Takeaways

```bash
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              🎓 RBAC LAB COMPLETE - KEY TAKEAWAYS 🎓               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Exercise 1: cluster-admin for everyone is dangerous"
echo "   → Always implement least privilege"
echo ""
echo "✅ Exercise 2: Namespace isolation"
echo "   → Use namespaces to separate teams and environments"
echo ""
echo "✅ Exercise 3: Developer access"
echo "   → Full dev access, read-only production, no prod secrets"
echo ""
echo "✅ Exercise 4: Operations access"
echo "   → Full workload access, no RBAC modification"
echo ""
echo "✅ Exercise 5: Security auditor"
echo "   → Read everything, modify nothing"
echo ""
echo "✅ Exercise 6: Access matrix verification"
echo "   → Document and verify permissions regularly"
echo ""
echo "🔐 Remember: RBAC is part of defense-in-depth, not the only protection!"
echo "════════════════════════════════════════════════════════════════════"
```

---

## Key Takeaways

### Core Concepts

- **RBAC** controls WHO can do WHAT on WHICH resources
- **Authentication** verifies identity; **Authorization** verifies permissions
- **Roles** define permissions; **Bindings** assign them to identities
- Use **ServiceAccounts** for applications, **Users/Groups** for humans

### Roles and Bindings

- **Role** + **RoleBinding**: Namespace-scoped permissions
- **ClusterRole** + **ClusterRoleBinding**: Cluster-wide permissions
- **ClusterRole** + **RoleBinding**: Reusable role, namespace-scoped binding
- Always specify the minimum required permissions (least privilege)

### Best Practices

- **Never use cluster-admin** for regular operations
- Use **namespaces** to isolate teams and environments
- Use **groups** for managing access at scale
- **Test permissions** before deploying with `kubectl auth can-i`
- Store RBAC manifests in **version control**
- **Audit** RBAC configurations regularly

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl auth can-i VERB RESOURCE` | Test if you can perform an action |
| `kubectl auth can-i --list` | List all your permissions |
| `kubectl auth can-i --as=USER` | Test as a different user |
| `kubectl get roles` | List Roles in current namespace |
| `kubectl get clusterroles` | List ClusterRoles |
| `kubectl get rolebindings` | List RoleBindings in current namespace |
| `kubectl get clusterrolebindings` | List ClusterRoleBindings |
| `kubectl describe role NAME` | View Role details |
| `kubectl describe rolebinding NAME` | View RoleBinding details |
| `kubectl create sa NAME` | Create a ServiceAccount |
| `kubectl auth reconcile -f FILE` | Apply RBAC config idempotently |

### Common API Groups

| API Group | Example Resources |
|-----------|-------------------|
| `""` (core) | pods, services, secrets, configmaps, namespaces |
| `apps` | deployments, replicasets, statefulsets, daemonsets |
| `batch` | jobs, cronjobs |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles |
| `networking.k8s.io` | ingresses, networkpolicies |

### Common Verbs

| Verb | HTTP Method | Description |
|------|-------------|-------------|
| `get` | GET | Read single resource |
| `list` | GET | List resources |
| `watch` | GET | Stream changes |
| `create` | POST | Create resource |
| `update` | PUT | Replace resource |
| `patch` | PATCH | Modify resource |
| `delete` | DELETE | Delete resource |
| `deletecollection` | DELETE | Delete multiple |

### Role Manifest Template

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-namespace
  name: my-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
```

### ClusterRole Manifest Template

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-clusterrole
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
```

### RoleBinding Manifest Template

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-rolebinding
  namespace: my-namespace
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: my-namespace
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role  # or ClusterRole
  name: my-role
```

### ClusterRoleBinding Manifest Template

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: my-clusterrolebinding
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: my-namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: my-clusterrole
```

### ServiceAccount Manifest Template

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-namespace
```

### Pod Using ServiceAccount Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: my-namespace
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: my-image:tag
```

---

## Cleanup (End of Lab)

```bash
# Delete all Roles created in this lab
kubectl delete role pod-reader developer configmap-editor pod-manager limited-role myapp-role 2>/dev/null || true

# Delete all ClusterRoles created in this lab
kubectl delete clusterrole node-reader secret-reader operations-manager security-auditor 2>/dev/null || true

# Delete all RoleBindings created in this lab
kubectl delete rolebinding demo-app-pod-manager team-pod-readers app-secret-reader limited-binding myapp-rolebinding viewer-binding editor-binding dev-team-full-access dev-team-prod-readonly ops-staging-access ops-prod-access 2>/dev/null || true

# Delete all ClusterRoleBindings created in this lab
kubectl delete clusterrolebinding cluster-viewer-nodes security-auditor-binding dangerous-dev-access 2>/dev/null || true

# Delete all ServiceAccounts created in this lab
kubectl delete sa my-app-sa demo-sa demo-app cluster-viewer app-with-secrets limited-sa myapp-sa team-alpha-viewer team-alpha-editor 2>/dev/null || true

# Delete test namespaces
kubectl delete namespace team-alpha rbac-test myapp securebank-dev securebank-staging securebank-prod securebank-security 2>/dev/null || true

# Clean up YAML files created during the lab (if in rbac-lab directory)
rm -f custom-sa.yaml pod-with-sa.yaml role-readonly.yaml role-developer.yaml role-specific.yaml 2>/dev/null || true
rm -f rbac-demo.yaml multi-subject-binding.yaml clusterrole-node-reader.yaml clusterrolebinding-demo.yaml 2>/dev/null || true
rm -f clusterrole-reuse.yaml builtin-role-demo.yaml rbac-test-env.yaml app-rbac.yaml 2>/dev/null || true
rm -f dangerous-setup.yaml namespaces.yaml team-accounts.yaml dev-rbac.yaml ops-rbac.yaml security-rbac.yaml check-access.sh 2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/rbac-lab

# Verify cleanup
echo "=== Remaining custom resources ==="
kubectl get roles --all-namespaces 2>/dev/null | grep -v kube-system || echo "No custom roles"
kubectl get rolebindings --all-namespaces 2>/dev/null | grep -v kube-system || echo "No custom rolebindings"
kubectl get clusterroles | grep -E "node-reader|secret-reader|operations|security-auditor" || echo "No custom clusterroles"
kubectl get clusterrolebindings | grep -E "cluster-viewer|security-auditor|dangerous" || echo "No custom clusterrolebindings"
```

---

## Troubleshooting Common Issues

### Permission Denied Errors

```bash
# Check if you have the required permissions
kubectl auth can-i create pods
kubectl auth can-i create pods --as=system:serviceaccount:default:my-sa

# Check what permissions you have
kubectl auth can-i --list
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa

# Common causes:
# - Missing RoleBinding or ClusterRoleBinding
# - Wrong namespace in binding
# - Typo in resource or verb
# - Missing apiGroup for non-core resources
```

### Role Not Working

```bash
# Check if the Role exists
kubectl get role my-role -n my-namespace

# Check the Role's rules
kubectl describe role my-role -n my-namespace

# Verify apiGroups are correct
# "" for core resources (pods, services, configmaps)
# "apps" for deployments, replicasets
# "batch" for jobs, cronjobs

# Check if RoleBinding references correct role
kubectl describe rolebinding my-binding -n my-namespace
```

### ClusterRole Not Working

```bash
# Check if using ClusterRoleBinding vs RoleBinding
# ClusterRoleBinding = cluster-wide access
# RoleBinding = namespace-scoped access (even for ClusterRole)

# For cluster-scoped resources (nodes, namespaces, PVs)
# You MUST use ClusterRoleBinding

# Check the binding
kubectl get clusterrolebinding my-binding -o yaml
```

### ServiceAccount Token Issues

```bash
# Verify the ServiceAccount exists
kubectl get sa my-sa -n my-namespace

# Check if Pod is using the correct ServiceAccount
kubectl get pod my-pod -o jsonpath='{.spec.serviceAccountName}'

# Verify token is mounted
kubectl exec my-pod -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

### Verbs Not Working as Expected

```bash
# Some resources have subresources
# pods/log, pods/exec, pods/portforward

# To access pod logs:
rules:
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]

# To exec into pods:
rules:
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]

# Test subresource access
kubectl auth can-i get pods --subresource=log
kubectl auth can-i create pods --subresource=exec
```

### RBAC Changes Not Taking Effect

```bash
# RBAC changes are immediate - no restart needed
# If not working, check:

# 1. Correct namespace
kubectl get rolebinding -n my-namespace

# 2. Correct subject (user/group/sa)
kubectl describe rolebinding my-binding -n my-namespace

# 3. Correct roleRef
kubectl get rolebinding my-binding -n my-namespace -o yaml | grep roleRef -A 3

# 4. For cached credentials, wait a few seconds
# Kubernetes caches authorization decisions briefly
```

---

## Additional Resources

- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
