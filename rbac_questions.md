# Kubernetes Role-Based Access Control (RBAC) – Test Questions

Use these questions to assess participant understanding after completing the RBAC lab.

---

## Section 1: Multiple Choice

**1. What is the primary purpose of Role-Based Access Control (RBAC) in Kubernetes?**

a) To encrypt data at rest  
b) To control who can perform what actions on which resources  
c) To manage container networking  
d) To schedule Pods on nodes  

---

**2. What is the difference between authentication and authorization in Kubernetes?**

a) They are the same thing  
b) Authentication verifies identity; authorization verifies permissions  
c) Authorization verifies identity; authentication verifies permissions  
d) Authentication is for users; authorization is for Pods  

---

**3. Which Kubernetes API object defines a set of permissions within a single namespace?**

a) ClusterRole  
b) RoleBinding  
c) Role  
d) ServiceAccount  

---

**4. Which Kubernetes API object grants cluster-wide permissions?**

a) Role  
b) RoleBinding  
c) ClusterRole with ClusterRoleBinding  
d) ServiceAccount  

---

**5. What happens when you bind a ClusterRole using a RoleBinding (not ClusterRoleBinding)?**

a) The permissions apply cluster-wide  
b) The binding fails with an error  
c) The permissions are scoped to the namespace of the RoleBinding  
d) The ClusterRole is automatically converted to a Role  

---

**6. Which of the following is NOT a valid subject kind in a RoleBinding?**

a) User  
b) Group  
c) ServiceAccount  
d) Pod  

---

**7. What command tests whether a user can perform a specific action?**

a) `kubectl auth test`  
b) `kubectl auth can-i`  
c) `kubectl check-permission`  
d) `kubectl rbac verify`  

---

**8. Which RBAC verb corresponds to the HTTP POST method?**

a) get  
b) update  
c) create  
d) patch  

---

**9. What is the purpose of a ServiceAccount in Kubernetes?**

a) To store user passwords  
b) To provide identity for Pods and other workloads  
c) To encrypt Secrets  
d) To manage node access  

---

**10. Which built-in ClusterRole provides read-only access to most resources in a namespace?**

a) cluster-admin  
b) admin  
c) edit  
d) view  

---

**11. What does the `apiGroups: [""]` entry in a Role rule refer to?**

a) All API groups  
b) The core API group (pods, services, configmaps, etc.)  
c) No API groups (invalid)  
d) Custom API groups only  

---

**12. Which verb would you use to allow watching for changes to resources?**

a) get  
b) list  
c) watch  
d) stream  

---

**13. What is the difference between `update` and `patch` verbs?**

a) They are identical  
b) `update` replaces the entire object; `patch` modifies specific fields  
c) `patch` replaces the entire object; `update` modifies specific fields  
d) `update` is for ConfigMaps; `patch` is for Secrets  

---

**14. Where is a ServiceAccount token mounted inside a Pod by default?**

a) /etc/kubernetes/token  
b) /var/run/secrets/kubernetes.io/serviceaccount  
c) /tmp/sa-token  
d) /root/.kube/token  

---

**15. Which ClusterRole provides full control over all resources in the entire cluster?**

a) admin  
b) edit  
c) cluster-admin  
d) super-user  

---

**16. How do you specify permissions for a subresource like pod logs?**

a) `resources: ["pods/logs"]`  
b) `resources: ["pods"], subresources: ["logs"]`  
c) `resources: ["logs"]`  
d) `resources: ["pods"], verbs: ["logs"]`  

---

**17. What happens if a Pod references a ServiceAccount that doesn't exist?**

a) The Pod starts with the default ServiceAccount  
b) The Pod fails to start  
c) A new ServiceAccount is automatically created  
d) The Pod starts without any ServiceAccount  

---

**18. Which command lists all permissions for the current user?**

a) `kubectl auth can-i --all`  
b) `kubectl auth can-i --list`  
c) `kubectl get permissions`  
d) `kubectl describe rbac`  

---

**19. What is the purpose of the `resourceNames` field in a Role rule?**

a) To rename resources  
b) To limit permissions to specific named resources  
c) To create aliases for resources  
d) To define resource quotas  

---

**20. Which identity represents all authenticated users in Kubernetes?**

a) `system:users`  
b) `system:authenticated`  
c) `system:all-users`  
d) `authenticated-users`  

---

## Section 2: True or False

**21. A Role can grant permissions to cluster-scoped resources like nodes and persistent volumes.**

☐ True  
☐ False  

---

**22. The same ClusterRole can be referenced by both RoleBindings and ClusterRoleBindings.**

☐ True  
☐ False  

---

**23. ServiceAccounts are namespaced resources.**

☐ True  
☐ False  

---

**24. The `cluster-admin` ClusterRole can be modified to remove certain permissions.**

☐ True  
☐ False  

---

**25. A RoleBinding in namespace "dev" can grant permissions to a ServiceAccount in namespace "prod".**

☐ True  
☐ False  

---

**26. Environment variable `KUBERNETES_SERVICE_HOST` is automatically set in all Pods.**

☐ True  
☐ False  

---

**27. The `edit` built-in role allows users to create and modify Roles and RoleBindings.**

☐ True  
☐ False  

---

**28. RBAC rules are additive; there is no "deny" rule.**

☐ True  
☐ False  

---

**29. A Pod can use multiple ServiceAccounts simultaneously.**

☐ True  
☐ False  

---

**30. The `kubectl auth can-i --as` flag allows testing permissions as a different identity.**

☐ True  
☐ False  

---

## Section 3: Fill in the Blank

**31. Complete the command to test if a ServiceAccount named `my-sa` in namespace `default` can create pods:**

```bash
kubectl auth can-i create pods --as=__________
```

---

**32. Complete the Role rule to grant read access to pods:**

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["__________", "list", "watch"]
```

---

**33. Complete the command to create a ServiceAccount imperatively:**

```bash
kubectl create __________ my-app-sa
```

---

**34. Complete the RoleBinding to bind a Role to a ServiceAccount:**

```yaml
subjects:
- kind: __________
  name: my-sa
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: my-role
```

---

**35. The four RBAC API objects are: Role, ClusterRole, RoleBinding, and __________.**

---

**36. Complete the command to list all ClusterRoles:**

```bash
kubectl get __________
```

---

**37. Complete the Pod spec to use a specific ServiceAccount:**

```yaml
spec:
  __________: my-app-sa
  containers:
  - name: app
    image: nginx
```

---

**38. Complete the Role rule to allow exec into pods:**

```yaml
rules:
- apiGroups: [""]
  resources: ["pods/__________"]
  verbs: ["create"]
```

---

**39. The built-in role that provides complete access within a namespace (but not RBAC) is called __________.**

---

**40. Complete the command to test permissions as a user named "alice":**

```bash
kubectl auth can-i get pods __________=alice
```

---

## Section 4: Short Answer

**41. Explain the difference between Role/RoleBinding and ClusterRole/ClusterRoleBinding. When would you use each?**

---

**42. What are three subject types that can be used in a RoleBinding? Provide an example use case for each.**

---

**43. Explain why RBAC alone is not sufficient for multi-tenant security in Kubernetes.**

---

**44. What is the principle of "least privilege" and how does it apply to RBAC?**

---

**45. Describe the relationship between ServiceAccounts and RBAC. How do they work together?**

---

**46. What are the four built-in user-facing ClusterRoles and what level of access does each provide?**

---

**47. A team needs to view resources across all namespaces but not modify anything. What RBAC configuration would you create?**

---

**48. Explain what happens when you try to create a RoleBinding that grants more permissions than you have.**

---

## Section 5: Practical Scenarios (SecureBank Multi-Team Access Control)

> **Context**: You are the Security Engineer at SecureBank, implementing RBAC for their Kubernetes-based banking platform. The platform has three teams: Development, Operations, and Security.

**49. Scenario: A developer accidentally deleted the production database because everyone had cluster-admin access. Write a Role manifest that gives developers:**
- Full access to pods, deployments, and services
- Read-only access to configmaps and secrets
- No ability to delete anything in production namespace

---

**50. Scenario: The operations team needs to deploy and troubleshoot applications in production. Write the RBAC manifests (ServiceAccount, Role, RoleBinding) that allow:**
- Creating and managing deployments, pods, and services
- Exec into pods for debugging
- Reading pod logs
- NO ability to create or modify Roles/RoleBindings

---

**51. Scenario: The security team needs to audit RBAC configurations across all namespaces. Write a ClusterRole and ClusterRoleBinding that allows:**
- Reading all Roles, ClusterRoles, RoleBindings, and ClusterRoleBindings
- Reading all Pods, Services, and Deployments (for context)
- NO write access to anything

---

**52. Scenario: An application needs to read its own ConfigMaps and Secrets but nothing else. Write the commands to:**
1. Create a ServiceAccount named `app-reader` in namespace `myapp`
2. Create a Role that allows reading ConfigMaps and Secrets only
3. Bind the Role to the ServiceAccount
4. Verify the ServiceAccount can read ConfigMaps but cannot create Pods

---

**53. Scenario: You discover that a developer has been using `kubectl auth can-i` to test their own permissions but doesn't know how to test as a ServiceAccount. Write the commands that demonstrate:**
1. How to test if the current user can create deployments
2. How to test if a ServiceAccount can create deployments
3. How to list all permissions for a ServiceAccount
4. How to test access to a subresource (like pod logs)

---

**54. Scenario: The development team requests access to the staging namespace with the built-in `edit` role. Write the RoleBinding manifest and then explain:**
1. What the `edit` role allows
2. What the `edit` role does NOT allow
3. Why using built-in roles is preferable to creating custom roles

---

**55. Scenario: A new microservice needs to:**
- Read Pods in its own namespace (for service discovery)
- Create and delete Jobs (for batch processing)
- Read Secrets (for configuration)
- Have no other permissions

Write a complete RBAC setup including ServiceAccount, Role, RoleBinding, and a Pod that uses this ServiceAccount.

---

**56. Scenario: During a security audit, you need to demonstrate that namespace isolation is working. Write the commands to:**
1. Create two namespaces: `team-a` and `team-b`
2. Create a ServiceAccount in `team-a`
3. Create a Role and RoleBinding that only grants access to `team-a`
4. Prove that the ServiceAccount cannot access resources in `team-b`
5. Show what error message appears when access is denied

---

---

## Answer Key

### Section 1: Multiple Choice

| Q | Answer | Explanation |
|---|--------|-------------|
| 1 | b | RBAC controls who can perform what actions on which resources |
| 2 | b | Authentication verifies identity; authorization verifies permissions |
| 3 | c | Role defines permissions within a single namespace |
| 4 | c | ClusterRole with ClusterRoleBinding grants cluster-wide permissions |
| 5 | c | ClusterRole + RoleBinding = namespace-scoped permissions |
| 6 | d | Pod is not a valid subject kind (User, Group, ServiceAccount are valid) |
| 7 | b | `kubectl auth can-i` tests authorization |
| 8 | c | create verb corresponds to HTTP POST |
| 9 | b | ServiceAccounts provide identity for Pods and workloads |
| 10 | d | view role provides read-only access |
| 11 | b | Empty string `""` refers to the core API group |
| 12 | c | watch verb allows streaming updates |
| 13 | b | update replaces entire object; patch modifies specific fields |
| 14 | b | Token mounted at /var/run/secrets/kubernetes.io/serviceaccount |
| 15 | c | cluster-admin has full cluster control |
| 16 | a | Subresources use format "resource/subresource" |
| 17 | b | Pod fails to start if ServiceAccount doesn't exist |
| 18 | b | `kubectl auth can-i --list` shows all permissions |
| 19 | b | resourceNames limits to specific named resources |
| 20 | b | `system:authenticated` represents all authenticated users |

### Section 2: True or False

| Q | Answer | Explanation |
|---|--------|-------------|
| 21 | False | Roles are namespaced; use ClusterRole for cluster-scoped resources |
| 22 | True | ClusterRoles can be bound at namespace or cluster level |
| 23 | True | ServiceAccounts are namespaced (each namespace has its own) |
| 24 | True | But changes are overwritten when API server restarts (auto-reconciliation) |
| 25 | True | RoleBindings can reference subjects in other namespaces |
| 26 | True | Kubernetes sets service discovery env vars automatically |
| 27 | False | edit role does NOT grant RBAC permissions |
| 28 | True | RBAC is additive only; no deny rules exist |
| 29 | False | A Pod can only use one ServiceAccount |
| 30 | True | --as flag allows impersonation for testing |

### Section 3: Fill in the Blank

| Q | Answer |
|---|--------|
| 31 | `system:serviceaccount:default:my-sa` |
| 32 | `get` |
| 33 | `serviceaccount` (or `sa`) |
| 34 | `ServiceAccount` |
| 35 | `ClusterRoleBinding` |
| 36 | `clusterroles` |
| 37 | `serviceAccountName` |
| 38 | `exec` |
| 39 | `admin` |
| 40 | `--as` |

### Section 4: Short Answer

**41.** 
- **Role/RoleBinding**: Namespace-scoped. Use for permissions within a single namespace. Cannot grant access to cluster-scoped resources (nodes, PVs).
- **ClusterRole/ClusterRoleBinding**: Cluster-scoped. Use for cluster-wide permissions, access to cluster-scoped resources, or reusable roles across namespaces.

Use Role/RoleBinding for: team-specific access, namespace isolation.
Use ClusterRole/ClusterRoleBinding for: cluster admin tasks, cross-namespace access, monitoring/logging agents.

**42.** Three subject types:
1. **User**: External user identity (e.g., from OIDC). Use for human operators, CI/CD pipelines running externally.
2. **Group**: Collection of users (e.g., "developers"). Use for team-based access, role-based organization.
3. **ServiceAccount**: Kubernetes-native identity for workloads. Use for applications running in cluster, automated processes.

**43.** RBAC alone is insufficient because:
- Anyone who can run arbitrary code in a Pod could potentially escape to the host
- Network policies are needed to isolate Pod communication
- Resource quotas prevent resource exhaustion attacks
- Pod security policies/standards restrict container privileges
- Secrets can be mounted by any Pod with access, regardless of RBAC

For hostile multi-tenant security, you also need: network policies, pod security, resource quotas, and potentially hypervisor-isolated containers or sandboxes.

**44.** Principle of least privilege:
- Grant only the minimum permissions required to perform a task
- No standing privileges; grant access only when needed
- Regularly audit and revoke unnecessary permissions
- Separate permissions by function (read vs write, dev vs prod)

In RBAC: Create specific Roles for specific tasks rather than using broad built-in roles. Don't grant `cluster-admin` when `view` suffices.

**45.** ServiceAccounts and RBAC relationship:
1. **ServiceAccount** provides identity (who you are)
2. **RBAC** provides authorization (what you can do)
3. ServiceAccount is created in a namespace
4. RoleBinding/ClusterRoleBinding associates the ServiceAccount with a Role/ClusterRole
5. When a Pod runs with that ServiceAccount, it inherits those permissions

The token at `/var/run/secrets/kubernetes.io/serviceaccount/token` is used for API authentication.

**46.** Four built-in user-facing ClusterRoles:
1. **cluster-admin**: Full control over entire cluster (superuser)
2. **admin**: Full control within a namespace, including RBAC
3. **edit**: Read/write access to most resources, no RBAC access
4. **view**: Read-only access to most resources, no secrets by default

**47.** View across all namespaces:
```yaml
# Use ClusterRole (view is built-in) with ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer
subjects:
- kind: User
  name: readonly-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
```

**48.** RBAC escalation prevention:
- Kubernetes prevents privilege escalation by default
- You cannot create a RoleBinding that grants permissions you don't have
- You cannot create Roles with permissions you don't have
- Error: "user cannot grant permissions they don't have"
- Exception: Users with `bind` and `escalate` permissions can bypass this

### Section 5: Practical Scenarios

**49.** (Developer Access - No Delete in Production)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-restricted
  namespace: production
rules:
# Full access (except delete) to pods, deployments, services
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Read-only for configmaps and secrets
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
# Note: "delete" verb is NOT included anywhere
```
**Key Learning**: Omitting the `delete` verb prevents accidental deletions while allowing development work.

**50.** (Operations Team RBAC)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-team
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-manager
  namespace: production
rules:
# Manage workloads
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["*"]
# Debug access
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"]
  verbs: ["create", "get"]
# NO roles/rolebindings access - missing from rules
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-team-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: ops-team
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ops-manager
```
**Key Learning**: Ops gets workload access but cannot escalate privileges by modifying RBAC.

**51.** (Security Auditor ClusterRole)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
# RBAC audit
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "clusterroles", "rolebindings", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Context resources
- apiGroups: [""]
  resources: ["pods", "services", "namespaces", "serviceaccounts"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch"]
# Note: NO write verbs anywhere
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-auditor-binding
subjects:
- kind: ServiceAccount
  name: security-auditor
  namespace: security
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: security-auditor
```
**Key Learning**: Security team can audit everything but modify nothing.

**52.** (Application Reader Commands)
```bash
# 1. Create ServiceAccount
kubectl create serviceaccount app-reader -n myapp

# 2. Create Role
kubectl create role configmap-secret-reader \
  --verb=get,list,watch \
  --resource=configmaps,secrets \
  -n myapp

# 3. Bind Role to ServiceAccount
kubectl create rolebinding app-reader-binding \
  --role=configmap-secret-reader \
  --serviceaccount=myapp:app-reader \
  -n myapp

# 4. Verify permissions
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:myapp:app-reader -n myapp
# Output: yes

kubectl auth can-i create pods \
  --as=system:serviceaccount:myapp:app-reader -n myapp
# Output: no
```
**Key Learning**: Minimal permissions for the specific task.

**53.** (Testing Permissions)
```bash
# 1. Test if current user can create deployments
kubectl auth can-i create deployments

# 2. Test if ServiceAccount can create deployments
kubectl auth can-i create deployments \
  --as=system:serviceaccount:default:my-sa

# 3. List all permissions for a ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:default:my-sa

# 4. Test access to subresource (pod logs)
kubectl auth can-i get pods --subresource=log \
  --as=system:serviceaccount:default:my-sa
# Or for exec:
kubectl auth can-i create pods --subresource=exec \
  --as=system:serviceaccount:default:my-sa
```
**Key Learning**: `--as` flag enables testing as any identity; `--subresource` tests specific subresources.

**54.** (Built-in Edit Role)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-edit
  namespace: staging
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
```

**Edit role ALLOWS**:
- Create, update, delete: pods, deployments, services, configmaps, secrets
- Port-forward, exec into pods
- View most resources

**Edit role does NOT allow**:
- Create/modify Roles or RoleBindings (no privilege escalation)
- Access to cluster-scoped resources
- Some sensitive operations like impersonation

**Why use built-in roles**:
1. Well-tested and maintained by Kubernetes
2. Automatically updated with new resources
3. Consistent across clusters
4. Less maintenance overhead
5. Following established security patterns

**55.** (Microservice RBAC Setup)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: batch-processor
  namespace: myapp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: batch-processor-role
  namespace: myapp
rules:
# Read pods for service discovery
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
# Manage jobs for batch processing
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "delete", "get", "list", "watch"]
# Read secrets for configuration
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: batch-processor-binding
  namespace: myapp
subjects:
- kind: ServiceAccount
  name: batch-processor
  namespace: myapp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: batch-processor-role
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-processor
  namespace: myapp
spec:
  serviceAccountName: batch-processor
  containers:
  - name: processor
    image: my-batch-app:latest
```
**Key Learning**: Each microservice should have its own ServiceAccount with minimal required permissions.

**56.** (Namespace Isolation Proof)
```bash
# 1. Create two namespaces
kubectl create namespace team-a
kubectl create namespace team-b

# 2. Create ServiceAccount in team-a
kubectl create serviceaccount team-a-sa -n team-a

# 3. Create Role and RoleBinding in team-a only
kubectl create role team-a-access \
  --verb=get,list,create,delete \
  --resource=pods,services \
  -n team-a

kubectl create rolebinding team-a-binding \
  --role=team-a-access \
  --serviceaccount=team-a:team-a-sa \
  -n team-a

# 4. Prove cannot access team-b
# Can access team-a:
kubectl auth can-i get pods \
  --as=system:serviceaccount:team-a:team-a-sa \
  -n team-a
# Output: yes

# Cannot access team-b:
kubectl auth can-i get pods \
  --as=system:serviceaccount:team-a:team-a-sa \
  -n team-b
# Output: no

# 5. Actual error message when trying to access:
kubectl get pods -n team-b \
  --as=system:serviceaccount:team-a:team-a-sa
# Error: pods is forbidden: User "system:serviceaccount:team-a:team-a-sa" 
# cannot list resource "pods" in API group "" in the namespace "team-b"
```
**Key Learning**: RoleBindings are namespace-scoped; they only grant access within their own namespace.

---

## Scoring Guide

| Score | Level |
|-------|-------|
| 50-56 | Expert – Ready for advanced Kubernetes security configurations |
| 42-49 | Proficient – Solid understanding, minor gaps |
| 34-41 | Intermediate – Review RBAC concepts and bindings |
| 25-33 | Beginner – Review core authorization concepts |
| 0-24 | Needs Review – Retake the lab exercises |
