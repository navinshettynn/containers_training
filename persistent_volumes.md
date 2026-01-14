# Kubernetes PersistentVolumes and PersistentVolumeClaims – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services, Secrets & ConfigMaps)

> **Important**: This lab assumes familiarity with kubectl commands, Pod concepts, and basic volume types (emptyDir, hostPath). If you haven't completed the previous labs, do those first.

> **Istio Service Mesh Note**: If your cluster has Istio installed, pods will have an additional sidecar container (`istio-proxy`). When using `kubectl exec` commands, you must specify the container name with `-c <container-name>` (e.g., `-c mysql`, `-c postgres`). The commands in this lab include the container specification for compatibility with Istio-enabled clusters.

### Verify Your Cluster is Running

```bash
# Check if kind cluster exists
# KIND creates a Kubernetes cluster inside Docker containers
kind get clusters

# Verify kubectl can communicate with the cluster
# This shows the API server and CoreDNS endpoints
kubectl cluster-info

# Check nodes are ready
# STATUS should be "Ready" for all nodes
kubectl get nodes
```

You should see output similar to:

```
NAME                         STATUS   ROLES           AGE   VERSION
kind-cluster-control-plane   Ready    control-plane   10m   v1.29.0
kind-cluster-worker          Ready    <none>          10m   v1.29.0
```

> **Why verify first?** Many storage operations require a healthy cluster. A misconfigured cluster can lead to PVCs stuck in Pending state, which is confusing when learning. Always verify your environment before starting.

---

## Learning Objectives

### Core Concepts

- Understand the **difference between ephemeral and persistent storage** in Kubernetes
- Learn what **PersistentVolumes (PV)** and **PersistentVolumeClaims (PVC)** are
- Understand the **PV/PVC binding** process
- Create and manage **PersistentVolumes** and **PersistentVolumeClaims**
- Use **StorageClasses** for dynamic provisioning
- Understand **access modes** and **reclaim policies**

### Practical Skills

- Create **static PersistentVolumes** with hostPath
- Create **PersistentVolumeClaims** to request storage
- Mount PVCs in **Pods and Deployments**
- Use the **local-path provisioner** in KIND for dynamic provisioning
- **Resize** PersistentVolumeClaims
- Understand **volume modes** (Filesystem vs Block)

### Intermediate Objectives (Optional)

- Configure **storage classes** with different parameters
- Implement **data migration** between volumes
- Use **volumeClaimTemplates** with StatefulSets
- Understand **CSI drivers** and their role

---

## Why Do We Need Persistent Storage?

Before diving into PersistentVolumes, let's understand **the problem they solve**.

### The Ephemeral Nature of Containers

In Kubernetes, **Pods are ephemeral**. They can be:
- Killed and restarted by the scheduler
- Moved to different nodes during scaling
- Replaced during rolling updates
- Terminated due to resource pressure

**What happens to data when a Pod dies?** It's gone! This is by design - containers should be stateless and disposable.

> **Real-world problem**: Imagine running a database in Kubernetes. Your PostgreSQL pod crashes at 3 AM. When it restarts, all your customer data is gone. This is catastrophic for any production system.

### The Storage Hierarchy

| Storage Type | Persistence | Survives Pod Restart? | Survives Node Restart? | Use Case |
|--------------|-------------|----------------------|------------------------|----------|
| **Container filesystem** | None | ❌ No | ❌ No | Temporary/scratch data |
| **emptyDir** | Pod lifetime | ❌ No | ❌ No | Shared scratch space between containers |
| **hostPath** | Node lifetime | ✅ Yes | ✅ Yes | Single-node development, testing |
| **PersistentVolume** | Independent | ✅ Yes | ✅ Yes | Production workloads, databases |

> **Key insight**: Each storage type has progressively longer lifetimes. PersistentVolumes exist independently of Pods - they survive Pod deletions, node failures, and even cluster upgrades.

### Why Not Just Use hostPath Everywhere?

You might think: "hostPath persists data, why not use it for everything?"

| Problem with hostPath | Impact |
|----------------------|--------|
| **Node-specific** | Data only exists on one node. If Pod moves, data is lost. |
| **No portability** | Pod spec hardcodes paths like `/mnt/data`. Not reusable. |
| **No capacity management** | No way to track or limit storage usage. |
| **Security risk** | Containers can access host filesystem. |
| **No abstraction** | Developers need to know infrastructure details. |

> **PV/PVC solves these**: Storage is abstracted. Developers request "I need 10GB of storage" without knowing where it physically lives. Administrators provision storage without knowing which applications will use it.

---

## Part 1: The PersistentVolume/PersistentVolumeClaim Model

### Understanding the Separation of Concerns

The PV/PVC model separates **storage provisioning** from **storage consumption**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│   ADMINISTRATOR (Storage Team)              DEVELOPER (Application Team)│
│   ─────────────────────────────             ─────────────────────────────│
│                                                                          │
│   "I provision storage resources"           "I need storage for my app"  │
│                │                                       │                 │
│                ▼                                       ▼                 │
│   ┌─────────────────────┐                   ┌─────────────────────┐     │
│   │  PersistentVolume   │◄──── Binding ────►│ PersistentVolumeClaim│     │
│   │  (Actual Storage)   │                   │ (Storage Request)    │     │
│   │                     │                   │                      │     │
│   │  - 100Gi capacity   │                   │  - 50Gi request      │     │
│   │  - SSD backed       │                   │  - ReadWriteOnce     │     │
│   │  - Located on NFS   │                   │  - Used by my Pod    │     │
│   └─────────────────────┘                   └─────────────────────┘     │
│                                                       │                 │
│                                                       ▼                 │
│                                             ┌─────────────────────┐     │
│                                             │        Pod          │     │
│                                             │  - Mounts the PVC   │     │
│                                             │  - Uses /data path  │     │
│                                             └─────────────────────┘     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Why this separation matters**:
> - **Security**: Developers don't need access to storage infrastructure
> - **Flexibility**: Storage can change (NFS → AWS EBS) without touching application code
> - **Scalability**: Administrators can pre-provision storage pools
> - **Self-service**: Developers can request storage without waiting for ops tickets

### Key Terminology

| Term | Description | Analogy |
|------|-------------|---------|
| **PersistentVolume (PV)** | A piece of storage in the cluster provisioned by an administrator or dynamically | A physical hard drive in a data center |
| **PersistentVolumeClaim (PVC)** | A request for storage by a user/Pod | A request form saying "I need X GB of storage" |
| **StorageClass** | Defines different "classes" of storage (fast, slow, replicated) | Storage tiers like "Premium SSD" vs "Standard HDD" |
| **Binding** | The process of matching a PVC to a suitable PV | Matching a storage request to available storage |
| **Provisioner** | Component that creates storage (static or dynamic) | The system that allocates storage resources |

---

## Part 2: Access Modes and Reclaim Policies

Before creating PVs, we need to understand two critical concepts that affect how storage behaves.

### Access Modes

Access modes define **how many nodes can mount the volume simultaneously** and **what operations they can perform**.

| Mode | Abbreviation | Description | Typical Use Case |
|------|--------------|-------------|------------------|
| **ReadWriteOnce** | RWO | Single node can mount read-write | Databases (MySQL, PostgreSQL) |
| **ReadOnlyMany** | ROX | Multiple nodes can mount read-only | Shared configuration, static assets |
| **ReadWriteMany** | RWX | Multiple nodes can mount read-write | Shared file storage, CMS uploads |
| **ReadWriteOncePod** | RWOP | Single Pod can mount read-write (K8s 1.22+) | Strict single-writer scenarios |

> **KIND Note**: hostPath volumes only support `ReadWriteOnce` because the data physically exists on one node. For RWX in production, you'd use NFS, GlusterFS, or cloud storage like AWS EFS.

> **Why does this matter?** If you try to mount an RWO volume on multiple nodes, you'll get scheduling failures. Understanding access modes prevents mysterious "Pod stuck in Pending" issues.

### Reclaim Policies

Reclaim policies define **what happens to the PV and its data when the PVC is deleted**.

| Policy | What Happens | When to Use | Risk Level |
|--------|--------------|-------------|------------|
| **Retain** | PV is kept, data preserved, manual cleanup needed | Production databases, critical data | Low (data safe) |
| **Delete** | PV and underlying storage are deleted automatically | Temporary data, dynamic provisioning | High (data lost!) |
| **Recycle** | (Deprecated) Data wiped (`rm -rf /volume/*`), PV reused | Legacy systems only | Medium |

> **Real-world scenario**: You have a PostgreSQL database PVC. A junior developer accidentally runs `kubectl delete pvc postgres-data`.
> - With **Delete policy**: Database and all customer data gone instantly. Disaster!
> - With **Retain policy**: PVC deleted, but PV and data preserved. You can recover.

**📝 Key Learning**: Always use `Retain` for important data. `Delete` is convenient but dangerous.

### Volume Status Lifecycle

PVs go through different states during their lifecycle:

| Status | Description | What It Means |
|--------|-------------|---------------|
| **Available** | PV is ready and not yet bound | Waiting for a matching PVC |
| **Bound** | PV is bound to a PVC | In use by an application |
| **Released** | PVC deleted, but resource not yet reclaimed | Data still exists, needs manual intervention |
| **Failed** | Volume has failed automatic reclamation | Something went wrong, check events |

```
Available ──► Bound ──► Released ──► Available (after manual cleanup)
                  │
                  └──► Failed (if reclamation fails)
```

> **Why "Released" not "Available"?** When a PVC with `Retain` policy is deleted, Kubernetes doesn't automatically make the PV available again. This prevents accidental data exposure - someone else's PVC could bind to your old database!

---

## Part 3: Creating Static PersistentVolumes

Now let's put theory into practice. We'll start with **static provisioning** - manually creating PVs.

### Create a Lab Directory

First, we create a dedicated directory for all our PV lab files. This keeps our work organized.

```bash
# Create and navigate to lab directory
# All our YAML files will be stored here
mkdir -p ~/pv-lab
cd ~/pv-lab
```

> **Why organize files?** When troubleshooting storage issues, you'll need to quickly find and modify configurations. A clean directory structure makes this much easier.

### Create Directories on KIND Node

Since we're using hostPath volumes, we need directories on the actual node (which is a Docker container in KIND):

```bash
# Create directories on the worker node
# These will be the physical storage locations for our PVs
docker exec kind-cluster-worker mkdir -p /mnt/data/pv1
docker exec kind-cluster-worker mkdir -p /mnt/data/pv2
docker exec kind-cluster-worker mkdir -p /mnt/data/pv3

# Set permissions so containers can write to these directories
# 777 is permissive - in production, use more restrictive permissions
docker exec kind-cluster-worker chmod 777 /mnt/data/pv1
docker exec kind-cluster-worker chmod 777 /mnt/data/pv2
docker exec kind-cluster-worker chmod 777 /mnt/data/pv3

# Verify the directories were created
docker exec kind-cluster-worker ls -la /mnt/data/
```

> **Why create directories first?** With `hostPath.type: DirectoryOrCreate`, Kubernetes can create directories. However, pre-creating them ensures correct permissions and lets us verify the storage location exists before deploying.

### Create Your First PersistentVolume

```bash
cat > pv-basic.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-basic
  labels:
    type: local              # Custom label - helps identify this PV
    environment: lab         # Custom label - useful for filtering
spec:
  storageClassName: manual   # Links this PV to PVCs requesting "manual" class
  capacity:
    storage: 1Gi             # This PV offers 1 gigabyte of storage
  accessModes:
    - ReadWriteOnce          # Only one node can mount this read-write
  persistentVolumeReclaimPolicy: Retain   # Keep data if PVC is deleted
  hostPath:
    path: /mnt/data/pv1      # Physical path on the node
    type: DirectoryOrCreate  # Create directory if it doesn't exist
EOF

kubectl apply -f pv-basic.yaml
```

> **What each field does**:
> - `storageClassName`: Acts like a "compatibility tag" - PVCs must request this same class to bind
> - `capacity.storage`: The size of this volume. PVCs requesting more won't bind.
> - `accessModes`: Defines mount capabilities. Must match or exceed PVC requirements.
> - `persistentVolumeReclaimPolicy`: Controls data fate when PVC is deleted
> - `hostPath.path`: The actual directory on the node where data lives

### View the PersistentVolume

Let's examine what we created:

```bash
# List all PVs - shows status, capacity, access modes
kubectl get pv

# Get detailed information about our specific PV
kubectl get pv pv-basic

# View complete details including events
# This is your go-to command for troubleshooting binding issues
kubectl describe pv pv-basic
```

> **What to look for in describe output**:
> - `Status`: Should be "Available" (waiting for a PVC)
> - `Claim`: Empty when unbound
> - `Source.HostPath.Path`: Confirms where data will be stored
> - `Events`: Shows binding history and any errors

### Create Multiple PVs with Different Sizes

In production, you'd pre-provision PVs of various sizes for different needs:

```bash
cat > pv-multiple.yaml <<'EOF'
---
# Small PV for configuration data, logs, etc.
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-small
  labels:
    size: small              # Label helps PVCs select specific PVs
spec:
  storageClassName: manual
  capacity:
    storage: 500Mi           # 500 megabytes - good for configs/logs
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete   # Auto-delete when PVC removed
  hostPath:
    path: /mnt/data/pv2
---
# Large PV for databases, media files, etc.
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-large
  labels:
    size: large              # Label for selective binding
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi             # 5 gigabytes - for larger workloads
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain   # Preserve data - important!
  hostPath:
    path: /mnt/data/pv3
EOF

kubectl apply -f pv-multiple.yaml
```

> **Why different reclaim policies?** `pv-small` uses `Delete` because it's for temporary data. `pv-large` uses `Retain` because larger volumes typically hold important data worth preserving.

### View All PVs

```bash
# List all PersistentVolumes
kubectl get pv
```

Expected output:

```
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   AGE
pv-basic   1Gi        RWO            Retain           Available           manual         2m
pv-small   500Mi      RWO            Delete           Available           manual         30s
pv-large   5Gi        RWO            Retain           Available           manual         30s
```

> **Understanding the output**:
> - `CAPACITY`: Storage size this PV offers
> - `ACCESS MODES`: RWO = ReadWriteOnce
> - `RECLAIM POLICY`: What happens when PVC is deleted
> - `STATUS`: Available = ready for binding
> - `CLAIM`: Empty = not bound to any PVC yet
> - `STORAGECLASS`: The class this PV belongs to

**📝 Key Learning**: Static PVs are pre-provisioned storage resources waiting to be claimed. This is the traditional "storage admin provisions, developer consumes" model.

---

## Part 4: Creating PersistentVolumeClaims

Now let's switch to the **developer perspective** - requesting storage without knowing infrastructure details.

### Create a Basic PVC

```bash
cat > pvc-basic.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-basic
spec:
  storageClassName: manual   # Must match PV's storageClassName
  accessModes:
    - ReadWriteOnce          # Request RWO access
  resources:
    requests:
      storage: 500Mi         # Request 500Mi of storage
EOF

kubectl apply -f pvc-basic.yaml
```

> **What happens when you apply this**:
> 1. Kubernetes looks for an **Available** PV with matching `storageClassName`
> 2. The PV must have **compatible** access modes (RWO covers RWO)
> 3. The PV's capacity must be **>= requested** size (500Mi, 1Gi, or 5Gi all work)
> 4. Kubernetes picks the **smallest suitable PV** (pv-small at 500Mi)
> 5. Both PVC and PV are marked as **Bound**

### View the PVC and Binding

```bash
# List all PVCs - shows bound status and volume name
kubectl get pvc

# Get specific PVC details
kubectl get pvc pvc-basic

# View complete details including bound PV name
kubectl describe pvc pvc-basic
```

> **What to look for**:
> - `Status`: Should be "Bound" (connected to a PV)
> - `Volume`: Shows which PV was selected (likely pv-small)
> - `Capacity`: Actual capacity of the bound PV
> - `Events`: Shows binding timeline

### Check PV Status After Binding

```bash
# See how PV status changed after binding
kubectl get pv
```

Notice that `pv-small` is now `Bound` to `default/pvc-basic`. The `CLAIM` column shows which PVC owns this PV.

> **Binding is exclusive**: Once bound, a PV can only be used by that specific PVC. Other PVCs cannot claim it, even if it has unused capacity.

### Understanding the Binding Algorithm

Kubernetes finds a PV that:

| Criterion | Description | Example |
|-----------|-------------|---------|
| **Matching storageClassName** | Exact string match required | "manual" == "manual" |
| **Compatible access modes** | PV modes must include all PVC modes | PV has RWO, PVC wants RWO ✓ |
| **Sufficient capacity** | PV capacity >= PVC request | PV has 500Mi, PVC wants 500Mi ✓ |
| **Available status** | PV must not be bound | Status == Available |
| **Selector match** | If PVC has selector, labels must match | Optional |

> **Important**: PVCs bind to the **smallest suitable PV**. A 500Mi request won't bind to a 5Gi PV if a 500Mi PV is available. This prevents waste.

### Create a PVC with Label Selector

Sometimes you want to bind to a **specific** PV. Use label selectors:

```bash
cat > pvc-selector.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-large-only
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi           # Need at least 2Gi
  selector:
    matchLabels:
      size: large            # ONLY bind to PVs with this label
EOF

kubectl apply -f pvc-selector.yaml
```

> **Why use selectors?**
> - Force binding to specific storage tiers (SSD vs HDD)
> - Ensure databases get their dedicated volumes
> - Control which PVs different teams can use

### Verify Specific Binding

```bash
# Check which PV was bound
kubectl get pvc pvc-large-only

# Verify it's the large PV
kubectl get pv
```

The PVC should bind specifically to `pv-large` (5Gi) because:
1. It's the only PV with label `size: large`
2. It has capacity >= 2Gi request
3. It was Available

**📝 Key Learning**: PVCs are storage requests that Kubernetes automatically matches to suitable PVs. Selectors give you control over which specific PV to use.

### Cleanup Part 4

```bash
# Delete the PVCs
kubectl delete pvc pvc-basic pvc-large-only

# Check PV status - notice they're now "Released" or "Available"
kubectl get pv
```

> **Observe the difference**: `pv-small` (Delete policy) might be gone. `pv-large` (Retain policy) shows "Released" status - data preserved but needs manual cleanup before reuse.

> **KIND Note**: With hostPath volumes, the `Delete` reclaim policy may show "Failed" status instead of deleting the PV. This is because the local-path provisioner cannot actually delete directories on the host filesystem. This is normal behavior in KIND. In cloud environments with proper CSI drivers (AWS EBS, GCP PD, Azure Disk), the Delete policy works correctly and removes the underlying storage.

---

## Part 5: Using PVCs in Pods

Now let's see the full flow: PVC mounted in a Pod, data written, Pod deleted, data survives.

### Create a PVC for Pod Use

```bash
cat > app-pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f app-pvc.yaml

# Verify it bound successfully
kubectl get pvc app-storage
```

### Create a Pod Using the PVC

```bash
cat > pod-with-pvc.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== PersistentVolume Demo ==="
      echo "Writing data to persistent storage..."
      echo "Hello from PersistentVolume!" > /data/hello.txt
      echo "Written at: $(date)" >> /data/hello.txt
      echo ""
      echo "Contents of /data/hello.txt:"
      cat /data/hello.txt
      echo ""
      echo "Sleeping to keep pod running..."
      sleep 3600
    volumeMounts:
    - name: storage              # Must match volume name below
      mountPath: /data           # Where the volume appears in container
  volumes:
  - name: storage                # Volume name (referenced by volumeMounts)
    persistentVolumeClaim:
      claimName: app-storage     # Name of the PVC to mount
EOF

kubectl apply -f pod-with-pvc.yaml
```

> **What happens when this Pod starts**:
> 1. Kubernetes sees the Pod needs PVC `app-storage`
> 2. The PVC is already bound to a PV (from our earlier step)
> 3. Kubernetes mounts the PV's hostPath at `/data` in the container
> 4. The container writes to `/data/hello.txt`
> 5. Data is actually written to the node's `/mnt/data/pv1/hello.txt`

### Verify the Pod is Using the PVC

```bash
# Wait for pod to be ready
kubectl get pods storage-demo
kubectl wait --for=condition=Ready pod/storage-demo --timeout=60s

# View the startup logs
kubectl logs storage-demo
```

You should see the contents of `/data/hello.txt` in the logs.

### Verify Data Persistence

Let's add more data and verify it persists:

```bash
# Check data in the pod
echo "=== Current data ==="
kubectl exec storage-demo -- cat /data/hello.txt

# Add more data
echo ""
echo "=== Adding more data ==="
kubectl exec storage-demo -- sh -c "echo 'More persistent data - $(date)' >> /data/hello.txt"

# Verify the addition
echo ""
echo "=== Updated contents ==="
kubectl exec storage-demo -- cat /data/hello.txt
```

### Delete Pod and Verify Data Survives

This is the **key test** - proving data outlives the Pod:

```bash
# Delete the pod
echo "Deleting pod storage-demo..."
kubectl delete pod storage-demo

# Verify PVC still exists and is bound
echo ""
echo "PVC status after pod deletion:"
kubectl get pvc app-storage
```

> **Notice**: The PVC remains `Bound`. The data is still in the PV. This is exactly what we want - application crashes shouldn't lose data.

### Create a New Pod with Same PVC

```bash
cat > pod-new.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo-new
spec:
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== New Pod Reading Existing Data ==="
      echo "Contents of /data/hello.txt (from previous pod):"
      echo "---"
      cat /data/hello.txt
      echo "---"
      echo ""
      echo "SUCCESS: Data persisted across pod restart!"
      sleep 3600
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: app-storage
EOF

kubectl apply -f pod-new.yaml
kubectl wait --for=condition=Ready pod/storage-demo-new --timeout=60s
kubectl logs storage-demo-new
```

**🎉 The data from the original pod is still there!**

> **Real-world impact**: This is how databases survive restarts. PostgreSQL crashes at 3 AM, Kubernetes restarts it, and all customer data is still there because it was on a PersistentVolume.

**📝 Key Learning**: PersistentVolumes decouple data lifecycle from Pod lifecycle. Pods come and go, but data persists.

### Cleanup Part 5

```bash
kubectl delete pod storage-demo-new
kubectl delete pvc app-storage
```

---

## Part 6: Dynamic Provisioning with StorageClasses

Static provisioning requires administrators to pre-create PVs. **Dynamic provisioning** automatically creates PVs when PVCs are created - true self-service storage!

### The Problem with Static Provisioning

| Challenge | Impact |
|-----------|--------|
| Administrator must pre-create PVs | Delays developer productivity |
| Hard to predict how many PVs needed | Either waste or shortage |
| Manual capacity planning | Ops burden |
| Different environments need different PVs | Configuration drift |

### The Dynamic Provisioning Solution

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│   Developer creates PVC ──►  StorageClass ──► Provisioner ──► PV Created │
│                                   │                             │        │
│   "I need 10Gi storage"          │                             │        │
│                                   │                             ▼        │
│                              Defines how                   PV automatically│
│                              to provision                  bound to PVC   │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

> **Why this matters**: Developers don't wait for storage. Create a PVC, get storage instantly. No tickets, no delays, no manual provisioning.

### Check Available StorageClasses

KIND comes with a built-in StorageClass called `standard`:

```bash
# List all StorageClasses
# KIND provides "standard" using the local-path-provisioner
kubectl get storageclass

# View detailed configuration
kubectl describe storageclass standard
```

> **What you'll see**:
> - `Provisioner`: rancher.io/local-path (KIND's default provisioner)
> - `ReclaimPolicy`: Delete (PV auto-deleted when PVC deleted)
> - `VolumeBindingMode`: WaitForFirstConsumer (more on this below)

### Understanding StorageClass Configuration

Let's examine what a StorageClass defines:

```bash
cat > storageclass-explained.yaml <<'EOF'
# This is for educational purposes - don't apply it
# KIND already has a working StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
  annotations:
    # Setting this makes it the default for PVCs without storageClassName
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path    # Which provisioner creates volumes
reclaimPolicy: Delete                  # What happens when PVC deleted
volumeBindingMode: WaitForFirstConsumer  # When to create the PV
allowVolumeExpansion: true             # Can PVCs request more space later?
# parameters:                          # Provider-specific settings
#   type: ssd                          # Example: request SSD storage
EOF

# Just for viewing - don't apply
cat storageclass-explained.yaml
```

### StorageClass Fields Explained

| Field | Description | Impact |
|-------|-------------|--------|
| `provisioner` | Which backend creates storage | Determines what storage type you get |
| `reclaimPolicy` | Delete or Retain when PVC deleted | Data safety vs convenience |
| `volumeBindingMode` | **Immediate**: Create PV as soon as PVC created<br>**WaitForFirstConsumer**: Wait until Pod needs it | WaitForFirstConsumer is smarter - considers Pod scheduling |
| `allowVolumeExpansion` | Can PVCs be resized? | Flexibility vs complexity |
| `parameters` | Provider-specific settings | Varies by provisioner |

> **WaitForFirstConsumer explained**: Imagine a Pod that needs to run on a specific node (due to nodeSelector). If the PV is created immediately on a random node, the Pod can't start! WaitForFirstConsumer delays PV creation until Kubernetes knows where the Pod will run.

### Create a PVC with Dynamic Provisioning

```bash
cat > pvc-dynamic.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  storageClassName: standard   # Use KIND's default StorageClass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f pvc-dynamic.yaml
```

### Watch Dynamic PV Creation

```bash
# The PVC might show Pending because of WaitForFirstConsumer
kubectl get pvc dynamic-pvc
```

> **Why Pending?** With `WaitForFirstConsumer`, the PV isn't created until a Pod actually needs it. This is normal!

Let's create a Pod to trigger PV creation:

```bash
cat > pod-dynamic.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== Dynamic Provisioning Demo ==="
      echo "This storage was automatically provisioned!"
      echo ""
      echo "Filesystem info:"
      df -h /data
      echo ""
      echo "Writing test data..."
      echo "Dynamically provisioned storage works!" > /data/test.txt
      cat /data/test.txt
      sleep 3600
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: dynamic-pvc
EOF

kubectl apply -f pod-dynamic.yaml
kubectl wait --for=condition=Ready pod/dynamic-demo --timeout=120s
```

### Verify Dynamic Provisioning

```bash
# Check PVC is now Bound
kubectl get pvc dynamic-pvc

# Check automatically created PV
# Notice the auto-generated name like pvc-xxxxx-xxxxx
kubectl get pv

# View Pod logs
kubectl logs dynamic-demo
```

> **What happened automatically**:
> 1. PVC was created, stayed Pending (WaitForFirstConsumer)
> 2. Pod was scheduled to a node
> 3. Provisioner saw the pending PVC and created a PV on that node
> 4. PVC bound to the new PV
> 5. Pod started with storage mounted

**📝 Key Learning**: Dynamic provisioning = self-service storage. No pre-provisioning needed. PVCs automatically get storage when Pods need it.

### Cleanup Part 6

```bash
kubectl delete pod dynamic-demo
kubectl delete pvc dynamic-pvc

# With Delete reclaim policy, the PV is automatically removed
kubectl get pv
```

---

## Part 7: Using PVCs with Deployments

Real applications use Deployments, not standalone Pods. Let's see how persistent storage works with Deployments.

### The Challenge with Deployments and Storage

| Scenario | What Happens |
|----------|--------------|
| Deployment with 3 replicas, RWO PVC | All 3 Pods try to mount the same volume. **Only works if all Pods land on same node!** |
| Pod killed by rolling update | New Pod gets same PVC, data preserved ✓ |
| Scale up | New Pods can't mount RWO volume on different nodes |

> **Important**: Standard Deployments + RWO PVCs work best with `replicas: 1`. For multi-replica stateful workloads, use **StatefulSets** (covered in advanced topics).

### Create a MySQL Deployment with Persistent Storage

```bash
cat > mysql-deployment.yaml <<'EOF'
# First, create the PVC for MySQL data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
# MySQL Deployment using the PVC
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  replicas: 1                    # Single replica for RWO volume
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword"    # In production, use Secrets!
        - name: MYSQL_DATABASE
          value: "testdb"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql    # MySQL data directory
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc         # Reference the PVC
EOF

kubectl apply -f mysql-deployment.yaml
```

> **Why mount at /var/lib/mysql?** This is where MySQL stores all its data files - databases, tables, indexes. By putting this on a PersistentVolume, the database survives Pod restarts.

### Wait for MySQL to Start

MySQL takes time to initialize, especially on first run:

```bash
# Watch pods come up
kubectl get pods -l app=mysql --watch
# Press Ctrl+C when Running

# Wait for readiness
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=180s
```

### Create Some Test Data in MySQL

```bash
# Get the pod name
MYSQL_POD=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')

# Connect to MySQL and create data
# This creates a table and inserts test records
# Note: -c mysql specifies the container (required if Istio sidecar is present)
kubectl exec -it $MYSQL_POD -c mysql -- mysql -uroot -prootpassword -e "
  USE testdb;
  CREATE TABLE messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  INSERT INTO messages (message) VALUES ('Hello from Kubernetes!');
  INSERT INTO messages (message) VALUES ('This data is persistent!');
  INSERT INTO messages (message) VALUES ('Even if the Pod crashes, data survives.');
  SELECT * FROM messages;
"
```

### Simulate Pod Failure and Recovery

This is the critical test - proving database data survives Pod termination:

```bash
# Record the current pod name
echo "Current pod: $MYSQL_POD"

# Delete the pod (Deployment will recreate it)
kubectl delete pod $MYSQL_POD

# Watch the new pod come up
echo "Waiting for new pod..."
kubectl get pods -l app=mysql --watch
# Press Ctrl+C when Running

# Wait for readiness
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=180s
```

### Verify Data Persistence

```bash
# Get the NEW pod name
MYSQL_POD=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $MYSQL_POD"

# Check if data still exists
# Note: -c mysql specifies the container (required if Istio sidecar is present)
kubectl exec -it $MYSQL_POD -c mysql -- mysql -uroot -prootpassword -e "USE testdb; SELECT * FROM messages;"
```

**🎉 The data survives pod deletion!**

> **What happened**:
> 1. Old Pod was deleted (simulating a crash)
> 2. Deployment controller created a new Pod
> 3. New Pod mounted the same PVC (still bound to the same PV)
> 4. MySQL found its existing data files and started normally
> 5. All our messages are still there!

**📝 Key Learning**: This is how databases achieve durability in Kubernetes. The PersistentVolume outlives any individual Pod, preserving data through crashes, updates, and restarts.

### Cleanup Part 7

```bash
kubectl delete deployment mysql
kubectl delete pvc mysql-pvc
```

---

## Part 8: PVC Expansion (Resizing)

What happens when your application needs more space? PVC expansion lets you grow storage without downtime.

### Prerequisites for Expansion

| Requirement | Description |
|-------------|-------------|
| StorageClass must have `allowVolumeExpansion: true` | Not all storage supports expansion |
| Can only **increase** size, never decrease | Data safety - can't shrink a filesystem |
| Some provisioners require Pod restart | Filesystem must be resized |

> **KIND Limitation**: The `standard` StorageClass in KIND has `allowVolumeExpansion: false`. The expansion commands in this section **will fail** with a "Forbidden" error. This demonstrates what happens when expansion isn't supported. In production environments with AWS EBS, GCP PD, or Azure Disk, expansion works seamlessly.

### Create an Expandable PVC

```bash
cat > pvc-expandable.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  storageClassName: standard   # Must have allowVolumeExpansion: true
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f pvc-expandable.yaml
```

### Create a Pod to Bind the PVC

```bash
cat > pod-expand.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: expand-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== Expansion Demo ==="
      while true; do
        echo "Current filesystem size:"
        df -h /data
        echo "---"
        sleep 30
      done
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

kubectl apply -f pod-expand.yaml
kubectl wait --for=condition=Ready pod/expand-demo --timeout=120s
```

### Check Current Size

```bash
# View PVC size
kubectl get pvc expandable-pvc

# View actual filesystem size in the Pod
kubectl exec expand-demo -- df -h /data
```

### Expand the PVC

```bash
# Patch the PVC to request more storage
# This is an in-place update - no need to delete/recreate
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Check the expansion status
kubectl get pvc expandable-pvc

# View detailed expansion status
kubectl describe pvc expandable-pvc | grep -A 5 "Conditions"
```

> **What happens during expansion**:
> 1. PVC requests new size (2Gi)
> 2. Controller tells provisioner to expand underlying storage
> 3. Condition shows `FileSystemResizePending` (waiting for filesystem resize)
> 4. On next Pod mount (or online, depending on provisioner), filesystem grows
> 5. Condition shows successful expansion

> **Note**: The local-path provisioner in KIND may not fully support online expansion. In cloud environments (AWS EBS, GCP PD), this works seamlessly.

**📝 Key Learning**: PVC expansion allows growing storage without downtime or data migration. This is crucial for production databases that grow over time.

### Cleanup Part 8

```bash
kubectl delete pod expand-demo
kubectl delete pvc expandable-pvc
```

---

## Part 9: ReadOnly PVC Mounting

Sometimes you need multiple Pods to read the same data without modification. Read-only mounts prevent accidental data corruption.

### Use Cases for Read-Only Mounts

| Scenario | Why Read-Only? |
|----------|----------------|
| Shared configuration | Multiple app instances read same config, none should modify |
| Static assets | Web servers serve images/CSS, shouldn't change them |
| Data science | Analysis jobs read datasets, shouldn't alter source data |
| Compliance | Audit logs must be immutable once written |

### Create a PVC with Pre-populated Data

```bash
# Create PVC
cat > readonly-pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f readonly-pvc.yaml

# Create a pod to populate data (the "writer")
cat > writer-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: data-writer
spec:
  containers:
  - name: writer
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== Populating shared data ==="
      echo "Application Configuration v1.0" > /data/config.txt
      echo "database_host=db.example.com" >> /data/config.txt
      echo "cache_ttl=3600" >> /data/config.txt
      echo "log_level=INFO" >> /data/config.txt
      echo ""
      echo "Configuration written:"
      cat /data/config.txt
      sleep 10
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: shared-data
  restartPolicy: Never
EOF

kubectl apply -f writer-pod.yaml
kubectl wait --for=condition=Ready pod/data-writer --timeout=60s
sleep 15
kubectl logs data-writer
kubectl delete pod data-writer
```

### Mount PVC as ReadOnly

Now let's mount the same PVC as read-only in another Pod:

```bash
cat > reader-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: data-reader
spec:
  containers:
  - name: reader
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "=== Reading shared data (read-only mount) ==="
      echo "Configuration contents:"
      cat /data/config.txt
      echo ""
      echo "Attempting to write (should fail)..."
      if echo "modified" >> /data/config.txt 2>&1; then
        echo "ERROR: Write succeeded! Mount is not read-only!"
      else
        echo "SUCCESS: Write blocked as expected (read-only mount)"
      fi
      sleep 3600
    volumeMounts:
    - name: data
      mountPath: /data
      readOnly: true          # THIS IS THE KEY - mount as read-only
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: shared-data
EOF

kubectl apply -f reader-pod.yaml
kubectl wait --for=condition=Ready pod/data-reader --timeout=60s
kubectl logs data-reader
```

> **What you should see**: The Pod can read the configuration but the write attempt fails with "Read-only file system".

**📝 Key Learning**: Read-only mounts add a layer of protection against accidental or malicious data modification. Use them whenever a Pod only needs to read data.

### Cleanup Part 9

```bash
kubectl delete pod data-reader
kubectl delete pvc shared-data
```

---

## Part 10: Volume Modes (Filesystem vs Block)

Most applications use **Filesystem** mode, but some need raw **Block** devices.

### Understanding Volume Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Filesystem** (default) | Volume is formatted with a filesystem, mounted as a directory | 99% of applications |
| **Block** | Raw block device, no filesystem | Databases with custom I/O, high performance requirements |

### When to Use Block Mode

| Scenario | Why Block? |
|----------|-----------|
| **Database engines** | Some DBs (like Cassandra, ScyllaDB) manage their own data layout |
| **Performance** | Eliminates filesystem overhead for very high I/O workloads |
| **Custom filesystems** | Application wants to format with specific filesystem |
| **VM workloads** | Virtual machines need raw disks |

### Check Volume Mode Support

```bash
# View StorageClass configuration
kubectl get storageclass standard -o yaml | grep volumeBindingMode
```

> **Note**: Block mode requires CSI drivers that support it. The local-path provisioner in KIND only supports Filesystem mode. In cloud environments, EBS, GCP PD, and Azure Disk support Block mode.

### Example Block Volume (Conceptual)

```yaml
# This is for illustration - won't work with KIND's local-path provisioner
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: block-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Block          # Request raw block device
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: block-demo
spec:
  containers:
  - name: app
    image: mydb:latest
    volumeDevices:           # Note: volumeDevices, not volumeMounts
    - name: data
      devicePath: /dev/xvda  # Raw device path, not a mount point
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: block-pvc
```

**📝 Key Learning**: Filesystem mode is the default and works for most applications. Block mode is a specialized feature for high-performance or custom storage needs.

---

## Scenario-Based Exercises: "DataVault" Backup Service

You've been hired by **DataVault Inc.** to help them set up persistent storage for their backup service on Kubernetes. The service needs to store customer backup data reliably.

> **Story Context**: DataVault had a major incident last quarter - their backup pods crashed and lost customer data because they were using `emptyDir` volumes. The CTO has mandated migrating to PersistentVolumes.

Each exercise combines concepts from previous parts to solve real problems you'll face in production.

```bash
# Setup: Create workspace
cd ~/pv-lab
```

---

### Exercise 1: Static PV for Archive Storage

**Scenario**: DataVault needs a dedicated 2Gi volume for archived backups. This is critical customer data that must be retained even if claims are accidentally deleted. The security team requires using a specific, pre-approved storage location.

**Requirements**:
- 2Gi capacity
- Retain policy (data must never be auto-deleted)
- Specific label for compliance tracking
- Bind using label selector for explicit control

**What you'll learn**: How to set up production-grade static provisioning with data protection.

#### Step 1: Create Directory on Node

First, we create a dedicated directory for archive storage. In production, this might be a mounted SAN or NAS.

```bash
# Create the archive directory on the worker node
# In production, this would be a mounted enterprise storage system
docker exec kind-cluster-worker mkdir -p /mnt/archive
docker exec kind-cluster-worker chmod 777 /mnt/archive

echo "Archive directory created on worker node"
```

> **Why a dedicated directory?** Isolating archive storage from other data makes backup/restore procedures simpler and reduces risk of accidental deletion.

#### Step 2: Create the PV with Protective Settings

```bash
cat > archive-pv.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: archive-pv
  labels:
    purpose: archive           # Compliance label - required for PVC selector
    environment: production    # Indicates production data
    retention: long-term       # Backup retention policy label
spec:
  storageClassName: archive    # Dedicated class for archive storage
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain   # CRITICAL: Never delete data
  hostPath:
    path: /mnt/archive
EOF

kubectl apply -f archive-pv.yaml
echo "Archive PV created with Retain policy"
```

> **Why Retain policy?** This is customer backup data. If someone accidentally deletes the PVC, we want the data preserved. The ops team can manually recover or clean up after investigation.

#### Step 3: Create the PVC with Explicit Binding

```bash
cat > archive-pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: archive-claim
  labels:
    team: backup-service
spec:
  storageClassName: archive    # Must match PV's storageClassName
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  selector:                    # EXPLICIT binding - security requirement
    matchLabels:
      purpose: archive         # Only bind to PVs labeled for archives
EOF

kubectl apply -f archive-pvc.yaml
```

> **Why use selector?** In a multi-tenant cluster, you don't want your archive data accidentally landing on shared storage. The selector ensures binding only to properly tagged, compliant PVs.

#### Step 4: Verify Binding

```bash
echo "=== PV Status ==="
kubectl get pv archive-pv

echo ""
echo "=== PVC Status ==="
kubectl get pvc archive-claim

echo ""
echo "=== Binding Details ==="
kubectl describe pvc archive-claim | grep -E "Volume:|Status:"
```

#### Step 5: Deploy Archive Manager Pod

```bash
cat > archive-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: archive-manager
spec:
  containers:
  - name: archiver
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "╔════════════════════════════════════════════╗"
      echo "║     DataVault Archive Manager v1.0         ║"
      echo "╚════════════════════════════════════════════╝"
      echo ""
      
      # Simulate backup operation
      BACKUP_FILE="/archive/backup-$(date +%Y%m%d-%H%M%S).txt"
      echo "Creating backup: $BACKUP_FILE"
      
      echo "=== Customer Backup Record ===" > $BACKUP_FILE
      echo "Backup Date: $(date)" >> $BACKUP_FILE
      echo "Customer ID: CUST-12345" >> $BACKUP_FILE
      echo "Data Size: 1.2GB" >> $BACKUP_FILE
      echo "Checksum: sha256-abc123..." >> $BACKUP_FILE
      echo "Status: COMPLETED" >> $BACKUP_FILE
      
      echo ""
      echo "Archive contents:"
      ls -la /archive/
      echo ""
      echo "Backup record:"
      cat $BACKUP_FILE
      
      sleep 3600
    volumeMounts:
    - name: archive-vol
      mountPath: /archive
  volumes:
  - name: archive-vol
    persistentVolumeClaim:
      claimName: archive-claim
EOF

kubectl apply -f archive-pod.yaml
kubectl wait --for=condition=Ready pod/archive-manager --timeout=60s
kubectl logs archive-manager
```

#### Step 6: Test Data Retention

Let's verify the Retain policy works:

```bash
echo "Deleting the pod and PVC..."
kubectl delete pod archive-manager
kubectl delete pvc archive-claim

echo ""
echo "=== PV Status After PVC Deletion ==="
kubectl get pv archive-pv
```

> **Expected Result**: PV shows "Released" status, NOT deleted. The data in `/mnt/archive` on the node is preserved!

```bash
# Verify data still exists on the node
echo ""
echo "=== Data Still Exists on Node ==="
docker exec kind-cluster-worker ls -la /mnt/archive/
docker exec kind-cluster-worker cat /mnt/archive/*.txt
```

**📝 Key Learning**: The Retain policy protected our customer backup data even when the PVC was deleted. In production, this prevents data loss from accidental deletions.

#### Cleanup Exercise 1

```bash
kubectl delete pv archive-pv
docker exec kind-cluster-worker rm -rf /mnt/archive
```

---

### Exercise 2: Dynamic Storage for Backup Jobs

**Scenario**: DataVault runs nightly backup jobs that need temporary workspace storage. The storage should be automatically provisioned and automatically cleaned up when jobs complete. No administrator involvement required.

**Requirements**:
- Self-service storage (no pre-provisioning)
- Auto-cleanup after job completion
- Job must write backup log to persistent storage

**What you'll learn**: How dynamic provisioning enables self-service storage for batch workloads.

#### Step 1: Create Job with Dynamic PVC

```bash
cat > backup-job.yaml <<'EOF'
# PVC for backup workspace - will be dynamically provisioned
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-workspace
spec:
  storageClassName: standard   # Use cluster's default dynamic provisioner
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# Backup Job using the PVC
apiVersion: batch/v1
kind: Job
metadata:
  name: nightly-backup
spec:
  template:
    spec:
      containers:
      - name: backup
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "╔════════════════════════════════════════════╗"
          echo "║       DataVault Nightly Backup Job         ║"
          echo "╚════════════════════════════════════════════╝"
          echo ""
          echo "Job started at $(date)"
          echo ""
          
          # Initialize backup log
          echo "=== Backup Log ===" > /backup/backup-log.txt
          echo "Started: $(date)" >> /backup/backup-log.txt
          
          # Simulate backup process
          for i in 1 2 3 4 5; do
            echo "Processing dataset $i of 5..."
            echo "  [$(date +%H:%M:%S)] Dataset $i - Processing" >> /backup/backup-log.txt
            sleep 2
            echo "  [$(date +%H:%M:%S)] Dataset $i - Completed" >> /backup/backup-log.txt
          done
          
          echo "Completed: $(date)" >> /backup/backup-log.txt
          echo "Status: SUCCESS" >> /backup/backup-log.txt
          
          echo ""
          echo "=== Backup Summary ==="
          cat /backup/backup-log.txt
          echo ""
          echo "Backup job completed successfully!"
        volumeMounts:
        - name: backup-storage
          mountPath: /backup
      restartPolicy: OnFailure
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: backup-workspace
  backoffLimit: 2
EOF

kubectl apply -f backup-job.yaml
```

> **Why PVC for a Job?** Even batch jobs often need persistent workspace:
> - Write logs that survive job restart
> - Store intermediate results for checkpointing
> - Keep output files after job completes

#### Step 2: Watch the Job Execute

```bash
# Watch job progress
kubectl get jobs nightly-backup --watch
# Press Ctrl+C when Complete shows 1/1

# View job logs
kubectl logs job/nightly-backup
```

#### Step 3: Verify Dynamic Provisioning

```bash
echo "=== PVC Status ==="
kubectl get pvc backup-workspace

echo ""
echo "=== Dynamically Created PV ==="
kubectl get pv

echo ""
echo "=== Storage Details ==="
kubectl describe pvc backup-workspace | grep -E "Volume:|Capacity:|StorageClass:"
```

> **Notice**: A PV with a generated name (like `pvc-xxxx-xxxx`) was automatically created. You didn't pre-provision anything!

#### Step 4: Clean Up (Automatic with Delete Policy)

```bash
echo "Deleting job and PVC..."
kubectl delete job nightly-backup
kubectl delete pvc backup-workspace

echo ""
echo "=== PV Status After Deletion ==="
kubectl get pv
```

> **Notice**: The dynamically provisioned PV was automatically deleted when the PVC was deleted. This is the Delete reclaim policy in action.

**📝 Key Learning**: Dynamic provisioning with Delete policy is perfect for temporary workloads. Storage is created on-demand and cleaned up automatically. No ops tickets, no manual cleanup.

---

### Exercise 3: Database with Persistent Storage

**Scenario**: DataVault stores metadata about backups in PostgreSQL. This is critical operational data that must survive pod restarts, deployments, and node failures. The database has experienced data loss before when pods crashed.

**Requirements**:
- PostgreSQL with persistent data directory
- Data must survive pod deletion
- Demonstrate actual data persistence

**What you'll learn**: How to run stateful databases safely in Kubernetes.

#### Step 1: Deploy PostgreSQL with PVC

```bash
cat > postgres-pv.yaml <<'EOF'
# PVC for PostgreSQL data
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
# PostgreSQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  replicas: 1                    # Single replica for database
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: datavault       # Database name
        - name: POSTGRES_USER
          value: admin
        - name: POSTGRES_PASSWORD
          value: secretpass      # Use Secrets in production!
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata  # Data subdirectory
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data    # PG data directory
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-data
---
# Service for PostgreSQL
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
EOF

kubectl apply -f postgres-pv.yaml
echo "Waiting for PostgreSQL to be ready (this takes ~60 seconds)..."
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=180s
```

> **Why PGDATA subdirectory?** PostgreSQL requires an empty directory for initialization. If we mount directly at `/var/lib/postgresql/data`, it might contain a `lost+found` directory from the filesystem, causing initialization to fail.

#### Step 2: Create Important Business Data

```bash
# Get pod name
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo "PostgreSQL pod: $POSTGRES_POD"

# Create tables and insert business data
# Note: -c postgres specifies the container (required if Istio sidecar is present)
kubectl exec -it $POSTGRES_POD -c postgres -- psql -U admin -d datavault -c "
-- Create backup metadata table
CREATE TABLE IF NOT EXISTS backup_jobs (
  id SERIAL PRIMARY KEY,
  customer_id VARCHAR(50) NOT NULL,
  backup_size_mb INTEGER,
  status VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some critical business records
INSERT INTO backup_jobs (customer_id, backup_size_mb, status) VALUES 
  ('CUST-001', 1024, 'COMPLETED'),
  ('CUST-002', 2048, 'COMPLETED'),
  ('CUST-003', 512, 'COMPLETED');

-- Show what we created
SELECT * FROM backup_jobs;
"
```

#### Step 3: Simulate Pod Crash

```bash
echo "=== Before Pod Deletion ==="
echo "Pod: $POSTGRES_POD"
# Note: -c postgres specifies the container (required if Istio sidecar is present)
kubectl exec -it $POSTGRES_POD -c postgres -- psql -U admin -d datavault -c "SELECT count(*) as record_count FROM backup_jobs;"

echo ""
echo "Simulating pod crash by deleting it..."
kubectl delete pod $POSTGRES_POD

echo ""
echo "Waiting for Deployment to create new pod..."
kubectl get pods -l app=postgres --watch
# Press Ctrl+C when new pod shows Running
```

#### Step 4: Wait for Recovery

```bash
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=180s
```

#### Step 5: Verify Data Survived

```bash
# Get NEW pod name
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo "New PostgreSQL pod: $POSTGRES_POD"

echo ""
echo "=== After Pod Recovery ==="
# Note: -c postgres specifies the container (required if Istio sidecar is present)
kubectl exec -it $POSTGRES_POD -c postgres -- psql -U admin -d datavault -c "SELECT * FROM backup_jobs;"
```

**🎉 All three customer records survived the pod crash!**

> **What happened behind the scenes**:
> 1. Original pod crashed/was deleted
> 2. PostgreSQL wrote all data to the PersistentVolume
> 3. Deployment controller created new pod
> 4. New pod mounted the same PVC/PV
> 5. PostgreSQL found existing data files and recovered
> 6. Business data intact!

**📝 Key Learning**: This is the entire point of PersistentVolumes - decoupling data lifecycle from pod lifecycle. Your database can crash, be rescheduled, or updated, and data survives.

#### Cleanup Exercise 3

```bash
kubectl delete deployment postgres
kubectl delete service postgres
kubectl delete pvc postgres-data
```

---

## Key Takeaways

### PersistentVolumes (PV)

| Concept | What You Learned |
|---------|------------------|
| **What they are** | Cluster-level storage resources, independent of Pods |
| **Who creates them** | Administrators (static) or provisioners (dynamic) |
| **Key properties** | Capacity, access modes, reclaim policy |
| **Lifecycle** | Exist independently, outlive Pods |

> **Key insight**: PVs separate storage management from application deployment. Developers don't need to know storage infrastructure details.

### PersistentVolumeClaims (PVC)

| Concept | What You Learned |
|---------|------------------|
| **What they are** | Requests for storage by Pods |
| **How binding works** | Kubernetes matches PVC requirements to available PVs |
| **Relationship to Pods** | Pods reference PVCs, not PVs directly |
| **Portability** | Same PVC can be used by different Pods over time |

> **Key insight**: PVCs are the developer interface to storage. Simple, portable, and abstracted from infrastructure.

### StorageClasses

| Concept | What You Learned |
|---------|------------------|
| **Purpose** | Enable dynamic provisioning, define storage "tiers" |
| **Key settings** | Provisioner, reclaim policy, binding mode |
| **Impact** | Self-service storage without admin intervention |

> **Key insight**: StorageClasses enable true storage-as-a-service in Kubernetes.

### Best Practices

| Practice | Why It Matters |
|----------|----------------|
| **Use Retain for important data** | Prevents accidental data loss |
| **Use dynamic provisioning** | Reduces ops burden, enables self-service |
| **Size requests appropriately** | Avoid waste, ensure capacity |
| **Use selectors for compliance** | Control where sensitive data lands |
| **Test persistence before production** | Verify your setup actually works |

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl get pv` | List PersistentVolumes |
| `kubectl get pvc` | List PersistentVolumeClaims |
| `kubectl get sc` | List StorageClasses |
| `kubectl describe pv <name>` | Detailed PV info (including bound PVC) |
| `kubectl describe pvc <name>` | Detailed PVC info (including events) |
| `kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'` | Resize PVC |
| `kubectl delete pvc <name>` | Delete PVC (and PV if Delete policy) |

### PV Manifest Template

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
  labels:
    type: local                        # Custom labels for selection
spec:
  storageClassName: manual             # Must match PVC
  capacity:
    storage: 10Gi                      # Volume size
  accessModes:
    - ReadWriteOnce                    # RWO, ROX, RWX, or RWOP
  persistentVolumeReclaimPolicy: Retain  # Retain or Delete
  hostPath:
    path: /mnt/data                    # Physical storage location
```

### PVC Manifest Template

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: manual             # Must match PV (or omit for default)
  accessModes:
    - ReadWriteOnce                    # Required access mode
  resources:
    requests:
      storage: 5Gi                     # Minimum size needed
  # selector:                          # Optional: select specific PVs
  #   matchLabels:
  #     type: local
```

### Pod with PVC Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: myimage:tag
    volumeMounts:
    - name: storage
      mountPath: /data                 # Where volume appears in container
      readOnly: false                  # Set true for read-only access
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc                # Reference to PVC
```

---

## Cleanup (End of Lab)

Clean up all resources created during the lab:

```bash
# Delete all PVCs
kubectl delete pvc --all

# Delete all manually created PVs
kubectl delete pv pv-basic pv-small pv-large archive-pv 2>/dev/null || true

# Clean up directories on KIND node
docker exec kind-cluster-worker rm -rf /mnt/data /mnt/archive

# Remove lab directory
cd ~
rm -rf ~/pv-lab

# Verify cleanup
echo "=== Final Cleanup Verification ==="
echo "PVs remaining:"
kubectl get pv
echo ""
echo "PVCs remaining:"
kubectl get pvc
```

---

## Troubleshooting Common Issues

### PVC Stuck in Pending

**Symptom**: PVC shows "Pending" status indefinitely.

**Common Causes and Solutions**:

```bash
# Check PVC events for the reason
kubectl describe pvc <name>
```

| Cause | Solution |
|-------|----------|
| **No matching PV** | Check storageClassName, accessModes, capacity match |
| **StorageClass doesn't exist** | `kubectl get sc` to verify class exists |
| **WaitForFirstConsumer** | Normal! Create a Pod that uses the PVC |
| **All suitable PVs bound** | Create more PVs or delete unused PVCs |

```bash
# Quick diagnostic
kubectl get pv                    # See available PVs
kubectl get sc                    # Verify StorageClass exists
kubectl get pvc <name> -o yaml    # See PVC requirements
```

### PV in Released State

**Symptom**: After PVC deletion, PV shows "Released" instead of "Available".

**Cause**: PV has `Retain` policy. Data is preserved but needs manual cleanup.

```bash
# Check the PV status and bound claim reference
kubectl get pv <name>
kubectl describe pv <name> | grep "Claim:"

# To make it available again (after backing up data if needed):
# 1. Delete the PV
kubectl delete pv <name>
# 2. Recreate it (or let dynamic provisioner create new one)
```

> **Warning**: If you manually clear the `spec.claimRef` to make a PV available, the next PVC that binds might get someone else's data!

### Pod Can't Mount PVC

**Symptom**: Pod stuck in ContainerCreating, events show mount errors.

```bash
# Check Pod events
kubectl describe pod <name>
```

| Cause | Solution |
|-------|----------|
| **PVC not bound** | Fix PVC binding first |
| **RWO already mounted** | PV mounted on another node |
| **Node affinity** | hostPath PV is on different node than Pod |
| **Permission denied** | Container user can't write to volume |

```bash
# Check what node the PV is on (for hostPath)
kubectl get pv <name> -o yaml | grep -A 3 hostPath

# Check what node the Pod is scheduled on
kubectl get pod <name> -o wide
```

### Data Not Persisting

**Symptom**: Data disappears after Pod restart.

```bash
# Verify PVC is actually bound
kubectl get pvc <name>

# Verify Pod is using the PVC (not emptyDir!)
kubectl get pod <name> -o yaml | grep -A 10 volumes:

# Check reclaim policy (might be Delete)
kubectl get pv -o custom-columns=NAME:.metadata.name,POLICY:.spec.persistentVolumeReclaimPolicy
```

### Volume Permission Denied

**Symptom**: Container can't write to mounted volume.

```bash
# Check container user
kubectl exec <pod> -- id

# For hostPath, check permissions on node
docker exec kind-cluster-worker ls -la /mnt/data

# Fix permissions (for testing only!)
docker exec kind-cluster-worker chmod 777 /mnt/data
```

Better solution - use securityContext:

```yaml
spec:
  securityContext:
    fsGroup: 1000       # Group ownership of mounted volumes
  containers:
  - name: app
    securityContext:
      runAsUser: 1000   # Run as this user
```

---

## Additional Resources

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Configure a Pod to Use a PersistentVolume](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)
- [Expanding Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
- [StatefulSets for Stateful Applications](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)