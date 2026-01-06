# Kubernetes ReplicaSets and Deployments – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the kubectl Commands Lab, Pods Lab, and Services Lab** (this lab builds on those skills)

> **Important**: This lab assumes familiarity with kubectl commands, Pod concepts (labels, selectors, probes), and Services. If you haven't completed the previous labs, do those first.

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

### Verify Metrics Server (Required for Autoscaling)

```bash
kubectl top nodes
```

If metrics-server is not installed, refer to the **kubectl Commands Lab** for installation instructions.

---

## Learning Objectives

### ReplicaSets

- Understand what a **ReplicaSet** is and why it's needed
- Learn about **reconciliation loops** and desired state
- Create and manage ReplicaSets declaratively
- **Scale** ReplicaSets up and down
- Understand the relationship between **Pods and ReplicaSets**
- Use **label selectors** to find related objects

### Deployments

- Understand how **Deployments** manage ReplicaSets
- Create and manage Deployments declaratively
- Perform **rolling updates** to deploy new versions
- Configure **rollout strategies** (Recreate, RollingUpdate)
- View and manage **rollout history**
- **Roll back** to previous versions
- Configure **health-aware rollouts**

### Intermediate Objectives (Optional)

- Configure **Horizontal Pod Autoscaling (HPA)**
- Understand **maxSurge** and **maxUnavailable** settings
- Configure **progressDeadlineSeconds** and **minReadySeconds**

---

## What is a ReplicaSet?

A ReplicaSet ensures a specified number of Pod replicas are running at all times.

| Feature | Description |
|---------|-------------|
| **Desired replicas** | Number of Pods you want running |
| **Current replicas** | Number of Pods actually running |
| **Selector** | Label query to find Pods to manage |
| **Pod template** | Specification for creating new Pods |

### Why Use ReplicaSets?

| Benefit | Description |
|---------|-------------|
| **Redundancy** | Multiple instances tolerate failures |
| **Scale** | Handle more requests with more instances |
| **Self-healing** | Failed Pods are automatically replaced |

### The Reconciliation Loop

ReplicaSets use a reconciliation loop:

1. **Observe** current state (how many Pods exist?)
2. **Compare** to desired state (how many should exist?)
3. **Act** to match desired state (create or delete Pods)

This loop runs continuously, ensuring the cluster converges to the desired state.

---

## What is a Deployment?

A Deployment provides declarative updates for Pods and ReplicaSets.

| Feature | Description |
|---------|-------------|
| **Manages ReplicaSets** | Creates and controls ReplicaSets |
| **Rollout strategies** | Controls how updates are applied |
| **Version history** | Tracks previous configurations |
| **Rollback support** | Easy revert to previous versions |

### Relationship Hierarchy

```
Deployment
    └── ReplicaSet (current version)
    │       └── Pod
    │       └── Pod
    │       └── Pod
    └── ReplicaSet (previous version - scaled to 0)
```

> **Note**: In production, you typically use Deployments rather than ReplicaSets directly. Deployments provide version management and rollout capabilities that ReplicaSets lack.

---

## Part 1: Creating and Managing ReplicaSets

### Create a Lab Directory

```bash
mkdir -p ~/replicasets-lab
cd ~/replicasets-lab
```

### Create a Simple ReplicaSet

```bash
cat > nginx-rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    app: nginx
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f nginx-rs.yaml
```

### ReplicaSet Spec Explained

| Field | Description |
|-------|-------------|
| `replicas` | Desired number of Pods |
| `selector.matchLabels` | Labels used to find Pods |
| `template` | Pod specification for new Pods |

> **Important**: The `selector.matchLabels` must be a subset of labels in `template.metadata.labels`.

### View the ReplicaSet

```bash
kubectl get replicasets
kubectl get rs nginx-rs
kubectl describe rs nginx-rs
```

### View the Pods Created by ReplicaSet

```bash
kubectl get pods -l app=nginx
kubectl get pods -l app=nginx -o wide
```

Notice that Pod names include the ReplicaSet name plus a random suffix.

### Find ReplicaSet from a Pod

```bash
# Get a pod name
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')

# Find the owner ReplicaSet
kubectl get pod $POD_NAME -o jsonpath='{.metadata.ownerReferences[0].name}'
```

### Observe Self-Healing

Delete a Pod and watch the ReplicaSet create a replacement:

```bash
# Terminal 1: Watch pods
kubectl get pods -l app=nginx --watch
```

```bash
# Terminal 2: Delete a pod
kubectl delete pod -l app=nginx --wait=false | head -1
```

The ReplicaSet immediately creates a new Pod to maintain the desired count!

### Cleanup Part 1

```bash
kubectl delete rs nginx-rs
```

---

## Part 2: Scaling ReplicaSets

### Create a ReplicaSet for Scaling

```bash
cat > web-rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f web-rs.yaml
kubectl get pods -l app=web
```

### Imperative Scaling

```bash
# Scale up
kubectl scale rs web-rs --replicas=5
kubectl get pods -l app=web

# Scale down
kubectl scale rs web-rs --replicas=2
kubectl get pods -l app=web
```

### Declarative Scaling (Recommended)

Edit the YAML file:

```bash
cat > web-rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f web-rs.yaml
kubectl get pods -l app=web
```

### Why Declarative is Better

| Approach | Pros | Cons |
|----------|------|------|
| Imperative | Quick, immediate | Not tracked, easy to forget |
| Declarative | Version controlled, reproducible | Requires file update |

> **Best Practice**: Always update your YAML files after imperative changes to keep configuration in sync.

### Cleanup Part 2

```bash
kubectl delete rs web-rs
```

---

## Part 3: ReplicaSet and Pod Adoption

ReplicaSets can adopt existing Pods that match their selector.

### Create a Standalone Pod

```bash
kubectl run orphan-pod --image=nginx:alpine --labels="app=adoptable"
kubectl get pods -l app=adoptable
```

### Create a ReplicaSet with Matching Selector

```bash
cat > adopt-rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: adopt-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: adoptable
  template:
    metadata:
      labels:
        app: adoptable
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

kubectl apply -f adopt-rs.yaml
```

### Observe Adoption

```bash
kubectl get pods -l app=adoptable
```

The ReplicaSet adopted the existing Pod and only created 2 new ones (total = 3)!

### Verify Ownership

```bash
kubectl get pods -l app=adoptable -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[0].name}{"\n"}{end}'
```

All Pods now show `adopt-rs` as their owner.

### Quarantining a Pod

Remove a Pod from the ReplicaSet by changing its labels:

```bash
# Get a pod name
POD_NAME=$(kubectl get pods -l app=adoptable -o jsonpath='{.items[0].metadata.name}')

# Remove the label (quarantine the pod)
kubectl label pod $POD_NAME app-

# Watch what happens
kubectl get pods --show-labels
```

The ReplicaSet creates a new Pod to replace the "missing" one, but the quarantined Pod still runs for debugging!

### Cleanup Part 3

```bash
kubectl delete rs adopt-rs
kubectl delete pod -l app=adoptable 2>/dev/null || true
kubectl delete pod orphan-pod 2>/dev/null || true
```

---

## Part 4: Creating Deployments

### Create Your First Deployment

```bash
cat > nginx-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
EOF

kubectl apply -f nginx-deployment.yaml
```

### View Deployment Status

```bash
kubectl get deployments
kubectl describe deployment nginx-deployment
```

### View the ReplicaSet Created by Deployment

```bash
kubectl get replicasets -l app=nginx
kubectl get rs -l app=nginx -o wide
```

Notice the ReplicaSet name includes a hash (e.g., `nginx-deployment-abc123`).

### View All Resources

```bash
kubectl get all -l app=nginx
```

This shows the Deployment, ReplicaSet, and Pods in the hierarchy.

### Deployment vs ReplicaSet Management

Try scaling the ReplicaSet directly:

```bash
RS_NAME=$(kubectl get rs -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl scale rs $RS_NAME --replicas=1
```

Wait a moment and check:

```bash
kubectl get rs $RS_NAME
```

The Deployment overrides the change! The reconciliation loop maintains desired state.

---

## Part 5: Updating Deployments (Rolling Updates)

### Update the Container Image

```bash
cat > nginx-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
  annotations:
    kubernetes.io/change-cause: "Update to nginx 1.25"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        kubernetes.io/change-cause: "Update to nginx 1.25"
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF

kubectl apply -f nginx-deployment.yaml
```

### Watch the Rolling Update

```bash
kubectl rollout status deployment nginx-deployment
```

### View ReplicaSets After Update

```bash
kubectl get rs -l app=nginx
```

You'll see two ReplicaSets:
- Old one scaled to 0
- New one with 3 replicas

### Imperative Image Update (Quick Method)

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.26 --record
kubectl rollout status deployment nginx-deployment
```

### View Rollout History

```bash
kubectl rollout history deployment nginx-deployment
```

### View Specific Revision

```bash
kubectl rollout history deployment nginx-deployment --revision=1
kubectl rollout history deployment nginx-deployment --revision=2
```

---

## Part 6: Rollback Strategies

### Roll Back to Previous Version

```bash
kubectl rollout undo deployment nginx-deployment
kubectl rollout status deployment nginx-deployment
```

### View History After Rollback

```bash
kubectl rollout history deployment nginx-deployment
```

Notice that the previous revision is now the latest.

### Roll Back to Specific Revision

```bash
# First, let's create another version
kubectl set image deployment/nginx-deployment nginx=nginx:alpine --record
kubectl rollout status deployment nginx-deployment

# View history
kubectl rollout history deployment nginx-deployment

# Roll back to revision 2
kubectl rollout undo deployment nginx-deployment --to-revision=2
kubectl rollout status deployment nginx-deployment
```

### Verify Current Image

```bash
kubectl get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Part 7: Rollout Strategies

Deployments support two rollout strategies.

### Recreate Strategy

Terminates all Pods before creating new ones:

```bash
cat > recreate-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-demo
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: recreate-demo
  template:
    metadata:
      labels:
        app: recreate-demo
    spec:
      containers:
      - name: app
        image: nginx:1.24
EOF

kubectl apply -f recreate-deployment.yaml
kubectl rollout status deployment recreate-demo
```

Watch the Recreate strategy in action:

```bash
# Terminal 1
kubectl get pods -l app=recreate-demo --watch
```

```bash
# Terminal 2
kubectl set image deployment/recreate-demo app=nginx:1.25
```

All Pods terminate before new ones start (brief downtime).

### RollingUpdate Strategy (Default)

```bash
cat > rolling-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-demo
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: rolling-demo
  template:
    metadata:
      labels:
        app: rolling-demo
    spec:
      containers:
      - name: app
        image: nginx:1.24
EOF

kubectl apply -f rolling-deployment.yaml
kubectl rollout status deployment rolling-demo
```

### RollingUpdate Parameters

| Parameter | Description |
|-----------|-------------|
| `maxSurge` | Max extra Pods during update (absolute or %) |
| `maxUnavailable` | Max unavailable Pods during update (absolute or %) |

Watch the RollingUpdate:

```bash
# Terminal 1
kubectl get pods -l app=rolling-demo --watch
```

```bash
# Terminal 2
kubectl set image deployment/rolling-demo app=nginx:1.25
```

Notice how Pods are replaced gradually, maintaining availability.

### Understanding maxSurge and maxUnavailable

| Setting | Effect |
|---------|--------|
| `maxSurge: 25%, maxUnavailable: 25%` | Default - balanced speed and availability |
| `maxSurge: 1, maxUnavailable: 0` | Safest - always at full capacity |
| `maxSurge: 100%, maxUnavailable: 0` | Blue/Green - new version fully up before old removed |
| `maxSurge: 0, maxUnavailable: 50%` | Fastest with 50% capacity reduction |

### Cleanup Part 7

```bash
kubectl delete deployment recreate-demo rolling-demo
```

---

## Part 8: Health-Aware Rollouts

### Configure minReadySeconds

Ensures Pods are healthy before continuing rollout:

```bash
cat > health-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-demo
spec:
  replicas: 4
  minReadySeconds: 10
  progressDeadlineSeconds: 120
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: health-demo
  template:
    metadata:
      labels:
        app: health-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
EOF

kubectl apply -f health-deployment.yaml
kubectl rollout status deployment health-demo
```

### Health-Aware Rollout Settings

| Setting | Description |
|---------|-------------|
| `minReadySeconds` | Wait time after Pod is ready before proceeding |
| `progressDeadlineSeconds` | Timeout before marking rollout as failed |

### Watch Slow Rollout

```bash
# Terminal 1: Watch pods
kubectl get pods -l app=health-demo --watch
```

```bash
# Terminal 2: Update image
kubectl set image deployment/health-demo app=nginx:1.25
```

Each Pod must be ready for 10 seconds before the next update proceeds.

### Demonstrate Rollout Timeout

Create a deployment with a bad image:

```bash
kubectl set image deployment/health-demo app=nginx:nonexistent
```

Watch the rollout stall:

```bash
kubectl rollout status deployment health-demo --timeout=30s
```

After the progressDeadlineSeconds, check status:

```bash
kubectl get deployment health-demo -o jsonpath='{.status.conditions[?(@.type=="Progressing")].status}'
```

Roll back to fix:

```bash
kubectl rollout undo deployment health-demo
kubectl rollout status deployment health-demo
```

### Cleanup Part 8

```bash
kubectl delete deployment health-demo
```

---

## Part 9: Horizontal Pod Autoscaling (HPA)

### Create a Deployment for Autoscaling

```bash
cat > hpa-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hpa-demo
  template:
    metadata:
      labels:
        app: hpa-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

kubectl apply -f hpa-deployment.yaml
```

### Create HPA

```bash
kubectl autoscale deployment hpa-demo \
  --min=2 \
  --max=10 \
  --cpu-percent=50
```

### View HPA

```bash
kubectl get hpa
kubectl describe hpa hpa-demo
```

### HPA Configuration

| Setting | Description |
|---------|-------------|
| `--min` | Minimum number of replicas |
| `--max` | Maximum number of replicas |
| `--cpu-percent` | Target CPU utilization percentage |

### View HPA YAML

```bash
kubectl get hpa hpa-demo -o yaml
```

### Cleanup Part 9

```bash
kubectl delete hpa hpa-demo
kubectl delete deployment hpa-demo
```

---

## Part 10: Revision History Management

### Configure Revision History Limit

```bash
cat > history-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: history-demo
spec:
  replicas: 2
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: history-demo
  template:
    metadata:
      labels:
        app: history-demo
      annotations:
        kubernetes.io/change-cause: "Initial deployment - nginx 1.24"
    spec:
      containers:
      - name: app
        image: nginx:1.24
EOF

kubectl apply -f history-deployment.yaml
```

### Create Multiple Revisions

```bash
# Revision 2
kubectl set image deployment/history-demo app=nginx:1.25 --record

# Revision 3
kubectl set image deployment/history-demo app=nginx:1.26 --record

# Revision 4
kubectl set image deployment/history-demo app=nginx:alpine --record
```

### View History

```bash
kubectl rollout history deployment history-demo
```

### Compare Revisions

```bash
kubectl rollout history deployment history-demo --revision=1
kubectl rollout history deployment history-demo --revision=4
```

### View ReplicaSets Kept for History

```bash
kubectl get rs -l app=history-demo
```

Multiple ReplicaSets are kept (scaled to 0) for rollback capability.

### Cleanup Part 10

```bash
kubectl delete deployment history-demo
```

---

## Exercises

### Exercise 1: ReplicaSet Management

Create and manage a ReplicaSet:

```bash
cd ~/replicasets-lab

# Create ReplicaSet
cat > exercise1-rs.yaml <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: exercise1-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: exercise1
  template:
    metadata:
      labels:
        app: exercise1
        version: v1
    spec:
      containers:
      - name: app
        image: nginx:alpine
EOF

kubectl apply -f exercise1-rs.yaml

# Verify
kubectl get rs exercise1-rs
kubectl get pods -l app=exercise1

# Scale up
kubectl scale rs exercise1-rs --replicas=5

# Verify
kubectl get pods -l app=exercise1

# Delete one pod and watch recovery
kubectl delete pod -l app=exercise1 --wait=false | head -1
kubectl get pods -l app=exercise1 --watch
```

Cleanup:

```bash
kubectl delete -f exercise1-rs.yaml
```

### Exercise 2: Complete Deployment Lifecycle

```bash
# Create deployment
cat > exercise2-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exercise2-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: exercise2
  template:
    metadata:
      labels:
        app: exercise2
      annotations:
        kubernetes.io/change-cause: "Initial - v1"
    spec:
      containers:
      - name: app
        image: nginx:1.24
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: exercise2-svc
spec:
  selector:
    app: exercise2
  ports:
  - port: 80
EOF

kubectl apply -f exercise2-deploy.yaml

# Wait for deployment
kubectl rollout status deployment exercise2-deploy

# Update to v2
kubectl set image deployment/exercise2-deploy app=nginx:1.25 --record

# Update to v3
kubectl set image deployment/exercise2-deploy app=nginx:1.26 --record

# View history
kubectl rollout history deployment exercise2-deploy

# Roll back to v2
kubectl rollout undo deployment exercise2-deploy
kubectl rollout status deployment exercise2-deploy

# Verify
kubectl rollout history deployment exercise2-deploy
```

Cleanup:

```bash
kubectl delete -f exercise2-deploy.yaml
```

### Exercise 3: Blue/Green Deployment Pattern

```bash
# Create Blue deployment (current version)
cat > blue-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.24
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
spec:
  selector:
    app: myapp
    version: blue
  ports:
  - port: 80
EOF

kubectl apply -f blue-deploy.yaml

# Verify blue is active
kubectl get pods -l version=blue
kubectl get svc myapp-svc -o jsonpath='{.spec.selector}'

# Create Green deployment (new version)
cat > green-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.25
EOF

kubectl apply -f green-deploy.yaml
kubectl rollout status deployment app-green

# Switch traffic to green
kubectl patch svc myapp-svc -p '{"spec":{"selector":{"app":"myapp","version":"green"}}}'

# Verify green is active
kubectl get svc myapp-svc -o jsonpath='{.spec.selector}'

# Remove blue deployment
kubectl delete deployment app-blue
```

Cleanup:

```bash
kubectl delete deployment app-green
kubectl delete svc myapp-svc
```

---

## Optional Advanced Exercises

### Exercise 4: Canary Deployment Pattern

```bash
# Create stable deployment
cat > stable-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: canary-app
      track: stable
  template:
    metadata:
      labels:
        app: canary-app
        track: stable
    spec:
      containers:
      - name: app
        image: nginx:1.24
---
apiVersion: v1
kind: Service
metadata:
  name: canary-app-svc
spec:
  selector:
    app: canary-app
  ports:
  - port: 80
EOF

kubectl apply -f stable-deploy.yaml

# Create canary deployment (10% traffic)
cat > canary-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary-app
      track: canary
  template:
    metadata:
      labels:
        app: canary-app
        track: canary
    spec:
      containers:
      - name: app
        image: nginx:1.25
EOF

kubectl apply -f canary-deploy.yaml

# Verify - service routes to both (90% stable, 10% canary)
kubectl get pods -l app=canary-app

# If canary is healthy, promote it
kubectl scale deployment app-stable --replicas=0
kubectl scale deployment app-canary --replicas=10
```

Cleanup:

```bash
kubectl delete deployment app-stable app-canary
kubectl delete svc canary-app-svc
```

### Exercise 5: Rollout with Pause/Resume

```bash
# Create deployment
kubectl create deployment pause-demo --image=nginx:1.24 --replicas=6

# Start rollout and pause
kubectl set image deployment/pause-demo nginx=nginx:1.25
kubectl rollout pause deployment pause-demo

# Check status (partially updated)
kubectl get pods -l app=pause-demo
kubectl rollout status deployment pause-demo

# Resume rollout
kubectl rollout resume deployment pause-demo
kubectl rollout status deployment pause-demo
```

Cleanup:

```bash
kubectl delete deployment pause-demo
```

---

## Key Takeaways

### ReplicaSets

- **ReplicaSets** ensure a specified number of Pod replicas are running
- The **reconciliation loop** continuously works to match desired state
- ReplicaSets use **label selectors** to identify which Pods to manage
- Pods can be **adopted** by ReplicaSets matching their labels
- **Quarantining** removes a Pod from a ReplicaSet for debugging

### Deployments

- **Deployments** manage ReplicaSets and provide version control
- **Rolling updates** allow zero-downtime deployments
- **Rollback** quickly reverts to previous versions
- **Rollout strategies** control how updates are applied
- **minReadySeconds** ensures stability before continuing rollout
- **HPA** automatically scales based on resource usage

### Best Practices

- Use **Deployments** instead of ReplicaSets directly
- Always use **declarative configuration** (YAML files)
- Include **change-cause annotations** for meaningful history
- Configure **readiness probes** for safe rollouts
- Set appropriate **resource requests/limits** for HPA

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl get rs` | List ReplicaSets |
| `kubectl get deployments` | List Deployments |
| `kubectl describe rs <name>` | ReplicaSet details |
| `kubectl describe deployment <name>` | Deployment details |
| `kubectl scale rs <name> --replicas=N` | Scale ReplicaSet |
| `kubectl scale deployment <name> --replicas=N` | Scale Deployment |
| `kubectl rollout status deployment <name>` | Watch rollout progress |
| `kubectl rollout history deployment <name>` | View rollout history |
| `kubectl rollout undo deployment <name>` | Rollback to previous |
| `kubectl rollout undo deployment <name> --to-revision=N` | Rollback to specific revision |
| `kubectl rollout pause deployment <name>` | Pause rollout |
| `kubectl rollout resume deployment <name>` | Resume rollout |
| `kubectl set image deployment/<name> <container>=<image>` | Update image |
| `kubectl autoscale deployment <name> --min=N --max=M --cpu-percent=P` | Create HPA |
| `kubectl get hpa` | List Horizontal Pod Autoscalers |

### Deployment Manifest Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  revisionHistoryLimit: 10
  minReadySeconds: 5
  progressDeadlineSeconds: 600
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        kubernetes.io/change-cause: "Description of change"
    spec:
      containers:
      - name: app
        image: myimage:v1
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

### ReplicaSet Manifest Template

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: my-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myimage:v1
        ports:
        - containerPort: 80
```

---

## Cleanup (End of Lab)

```bash
# Delete all resources created in this lab
kubectl delete deployment nginx-deployment 2>/dev/null || true
kubectl delete rs nginx-rs web-rs adopt-rs 2>/dev/null || true
kubectl delete deployment recreate-demo rolling-demo health-demo hpa-demo history-demo 2>/dev/null || true
kubectl delete deployment exercise1-rs exercise2-deploy 2>/dev/null || true
kubectl delete deployment app-blue app-green app-stable app-canary pause-demo 2>/dev/null || true
kubectl delete svc exercise2-svc myapp-svc canary-app-svc 2>/dev/null || true
kubectl delete hpa hpa-demo 2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/replicasets-lab

# Verify cleanup
kubectl get deployments
kubectl get rs
kubectl get hpa
```

---

## Troubleshooting Common Issues

### ReplicaSet Not Creating Pods

```bash
# Check ReplicaSet status
kubectl describe rs <name>

# Common causes:
# - Selector doesn't match template labels
# - Invalid image
# - Resource constraints (check events)
```

### Deployment Rollout Stuck

```bash
# Check rollout status
kubectl rollout status deployment <name>

# Check for issues
kubectl describe deployment <name>

# Common causes:
# - Readiness probe failing
# - Image pull errors
# - Resource limits exceeded
# - progressDeadlineSeconds exceeded

# To fix, either:
# 1. Fix the issue and wait
# 2. Roll back: kubectl rollout undo deployment <name>
```

### Pods Not Scaling Down

```bash
# Check for Pod disruption budgets
kubectl get pdb

# Check if pods are terminating
kubectl get pods | grep Terminating

# Force delete if stuck
kubectl delete pod <name> --force --grace-period=0
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl describe hpa <name>

# Verify metrics-server is running
kubectl top nodes
kubectl top pods

# Common causes:
# - Metrics server not installed
# - No resource requests defined on pods
# - Target already at min/max
```

### Rollback Not Working

```bash
# Check revision history
kubectl rollout history deployment <name>

# Verify revisionHistoryLimit
kubectl get deployment <name> -o jsonpath='{.spec.revisionHistoryLimit}'

# If history is empty, old ReplicaSets were deleted
```

---

## Additional Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Rolling Update Deployment](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Managing Resources](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)


