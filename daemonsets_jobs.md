# Kubernetes DaemonSets and Jobs – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services, ReplicaSets & Deployments)

> **Important**: This lab assumes familiarity with kubectl commands, Pod concepts, Services, and Deployments. If you haven't completed the previous labs, do those first.

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

### DaemonSets

- Understand what a **DaemonSet** is and when to use it
- Learn how DaemonSets differ from **ReplicaSets and Deployments**
- Create and manage DaemonSets
- Use **node selectors** to limit DaemonSet scope
- Perform **rolling updates** on DaemonSets

### Jobs

- Understand the **Job object** and its use cases
- Learn different **job patterns** (one-shot, parallel, work queue)
- Handle **job failures** and retries
- Configure **parallelism** and **completions**
- Create and manage **CronJobs** for scheduled tasks

### Intermediate Objectives (Optional)

- Configure DaemonSet **tolerations** for special nodes
- Implement **work queue** patterns with Jobs
- Configure **job history limits** and cleanup policies

---

## Part 1: Understanding DaemonSets

### What is a DaemonSet?

A DaemonSet ensures that **one copy of a Pod runs on each node** (or a subset of nodes) in the cluster.

| Feature | Description |
|---------|-------------|
| **One per node** | Exactly one Pod per matching node |
| **Auto-scheduling** | Pods automatically added to new nodes |
| **Node-aware** | Uses node selectors for targeting |
| **Self-healing** | Replaces Pods on node failure |

### DaemonSet vs ReplicaSet/Deployment

| Aspect | DaemonSet | ReplicaSet/Deployment |
|--------|-----------|----------------------|
| **Pod placement** | One per node | Any nodes with capacity |
| **Replicas** | Determined by node count | Explicitly specified |
| **Use case** | Node-level services | Application workloads |
| **Scaling** | Automatic with cluster | Manual or HPA |

### Common DaemonSet Use Cases

| Use Case | Example |
|----------|---------|
| Log collection | Fluentd, Filebeat |
| Monitoring | Node Exporter, Datadog agent |
| Networking | CNI plugins, kube-proxy |
| Storage | CSI node drivers |
| Security | Intrusion detection, antivirus |

---

## Part 2: Creating DaemonSets

### Create a Lab Directory

```bash
mkdir -p ~/daemonsets-jobs-lab
cd ~/daemonsets-jobs-lab
```

### Create a Simple DaemonSet

```bash
cat > simple-daemonset.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: simple-daemon
  labels:
    app: simple-daemon
spec:
  selector:
    matchLabels:
      app: simple-daemon
  template:
    metadata:
      labels:
        app: simple-daemon
    spec:
      containers:
      - name: daemon
        image: busybox:latest
        command: ["sh", "-c", "while true; do echo 'Daemon running on' $(hostname); sleep 30; done"]
        resources:
          limits:
            memory: 64Mi
            cpu: 50m
          requests:
            memory: 32Mi
            cpu: 25m
      terminationGracePeriodSeconds: 10
EOF

kubectl apply -f simple-daemonset.yaml
```

### View DaemonSet Status

```bash
kubectl get daemonsets
kubectl get ds simple-daemon
```

Output shows:

```
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
simple-daemon   2         2         2       2            2           <none>          30s
```

| Column | Description |
|--------|-------------|
| DESIRED | Number of nodes that should run the Pod |
| CURRENT | Number of nodes running the Pod |
| READY | Number of Pods that are ready |
| UP-TO-DATE | Number of Pods with latest template |
| AVAILABLE | Number of Pods available |

### View Pods Created by DaemonSet

```bash
kubectl get pods -l app=simple-daemon -o wide
```

Notice one Pod runs on each node (control-plane and worker).

### Describe DaemonSet

```bash
kubectl describe ds simple-daemon
```

### View Pod Logs

```bash
# Get logs from all DaemonSet pods
kubectl logs -l app=simple-daemon

# Get logs from a specific node's pod
POD_NAME=$(kubectl get pods -l app=simple-daemon -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME
```

---

## Part 3: DaemonSet with Node Selector

Limit DaemonSet to specific nodes using labels.

### Add Labels to Nodes

```bash
# View current node labels
kubectl get nodes --show-labels

# Add custom label to worker node
kubectl label nodes kind-cluster-worker workload=application

# Verify label
kubectl get nodes -l workload=application
```

### Create DaemonSet with Node Selector

```bash
cat > selective-daemonset.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: selective-daemon
  labels:
    app: selective-daemon
spec:
  selector:
    matchLabels:
      app: selective-daemon
  template:
    metadata:
      labels:
        app: selective-daemon
    spec:
      nodeSelector:
        workload: application
      containers:
      - name: daemon
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: 64Mi
            cpu: 50m
EOF

kubectl apply -f selective-daemonset.yaml
```

### Verify Selective Scheduling

```bash
kubectl get pods -l app=selective-daemon -o wide
```

Only one Pod runs (on the labeled worker node).

### Add Label to Another Node

```bash
# Add label to control-plane
kubectl label nodes kind-cluster-control-plane workload=application

# Watch new Pod appear
kubectl get pods -l app=selective-daemon -o wide
```

### Remove Label to See Pod Removal

```bash
# Remove label from control-plane
kubectl label nodes kind-cluster-control-plane workload-

# Watch Pod disappear
kubectl get pods -l app=selective-daemon -o wide
```

---

## Part 4: DaemonSet Rolling Updates

DaemonSets support rolling updates similar to Deployments.

### View Update Strategy

```bash
kubectl get ds simple-daemon -o jsonpath='{.spec.updateStrategy}'
```

Default strategy is `RollingUpdate`.

### Create DaemonSet with Update Configuration

```bash
cat > update-daemonset.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: update-daemon
  labels:
    app: update-daemon
spec:
  selector:
    matchLabels:
      app: update-daemon
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  minReadySeconds: 10
  template:
    metadata:
      labels:
        app: update-daemon
        version: v1
    spec:
      containers:
      - name: daemon
        image: nginx:1.24
        resources:
          limits:
            memory: 64Mi
            cpu: 50m
EOF

kubectl apply -f update-daemonset.yaml
kubectl rollout status ds update-daemon
```

### Perform Rolling Update

```bash
# Update the image
kubectl set image ds update-daemon daemon=nginx:1.25

# Watch the rollout
kubectl rollout status ds update-daemon
```

### View Rollout History

```bash
kubectl rollout history ds update-daemon
```

### Rollback DaemonSet

```bash
kubectl rollout undo ds update-daemon
kubectl rollout status ds update-daemon
```

### DaemonSet Update Strategies

| Strategy | Description |
|----------|-------------|
| `RollingUpdate` | Updates Pods one at a time (default) |
| `OnDelete` | Only updates Pods when manually deleted |

---

## Part 5: Practical DaemonSet - Log Collector

Create a realistic log collector DaemonSet.

```bash
cat > log-collector.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  labels:
    app: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "Log collector started on $(hostname)"
          while true; do
            echo "Collecting logs at $(date)"
            ls -la /var/log/containers/ 2>/dev/null || echo "No container logs found"
            sleep 60
          done
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        resources:
          limits:
            memory: 128Mi
            cpu: 100m
          requests:
            memory: 64Mi
            cpu: 50m
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
EOF

kubectl apply -f log-collector.yaml
```

### Verify Log Collection

```bash
kubectl get ds log-collector
kubectl logs -l app=log-collector --tail=10
```

### Cleanup DaemonSets Section

```bash
kubectl delete ds simple-daemon selective-daemon update-daemon log-collector
kubectl label nodes kind-cluster-worker workload-
```

---

## Part 6: Understanding Jobs

### What is a Job?

A Job creates Pods that run until **successful completion** (exit code 0).

| Feature | Description |
|---------|-------------|
| **Finite** | Runs until completion, not continuously |
| **Retries** | Automatically retries on failure |
| **Completion tracking** | Tracks successful completions |
| **Parallelism** | Can run multiple Pods in parallel |

### Job vs Deployment

| Aspect | Job | Deployment |
|--------|-----|------------|
| **Lifecycle** | Runs to completion | Runs continuously |
| **Restart** | On failure only | Always |
| **Use case** | Batch processing | Services |
| **Scaling** | Fixed completions | Dynamic replicas |

### Job Use Cases

| Use Case | Example |
|----------|---------|
| Data processing | ETL pipelines, data import |
| Batch operations | Report generation, cleanup |
| One-time tasks | Database migrations, backups |
| Parallel processing | Image processing, ML training |

---

## Part 7: One-Shot Jobs

### Create a Simple One-Shot Job

```bash
cat > oneshot-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: oneshot
spec:
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Starting job'; sleep 5; echo 'Job completed successfully'; exit 0"]
      restartPolicy: OnFailure
EOF

kubectl apply -f oneshot-job.yaml
```

### Watch Job Progress

```bash
kubectl get jobs oneshot --watch
```

### View Job Details

```bash
kubectl describe job oneshot
```

### View Job Pod Logs

```bash
kubectl logs -l job-name=oneshot
```

### View Completed Pod

```bash
kubectl get pods -l job-name=oneshot
```

Note: Completed Pods remain for log inspection.

### Job Spec Explained

| Field | Description |
|-------|-------------|
| `completions` | Number of successful completions needed (default: 1) |
| `parallelism` | Number of Pods running in parallel (default: 1) |
| `backoffLimit` | Number of retries before marking failed (default: 6) |
| `activeDeadlineSeconds` | Maximum runtime before termination |
| `ttlSecondsAfterFinished` | Time to keep job after completion |

---

## Part 8: Handling Job Failures

### Create a Failing Job

```bash
cat > failing-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Starting...'; sleep 2; echo 'Failing!'; exit 1"]
      restartPolicy: OnFailure
EOF

kubectl apply -f failing-job.yaml
```

### Watch Retries

```bash
kubectl get pods -l job-name=failing-job --watch
```

The Pod restarts up to `backoffLimit` times.

### Check Job Status

```bash
kubectl describe job failing-job
```

You'll see the job eventually fails after retries are exhausted.

### Restart Policy Options

| Policy | Behavior |
|--------|----------|
| `OnFailure` | Restart container in same Pod |
| `Never` | Create new Pod for each retry |

### Compare Restart Policies

With `restartPolicy: Never`:

```bash
cat > failing-job-never.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job-never
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Attempt'; exit 1"]
      restartPolicy: Never
EOF

kubectl apply -f failing-job-never.yaml
sleep 10
kubectl get pods -l job-name=failing-job-never
```

Multiple failed Pods are created instead of restarting one.

### Cleanup Failing Jobs

```bash
kubectl delete job failing-job failing-job-never
```

---

## Part 9: Parallel Jobs

### Fixed Completions Pattern

Run multiple completions with limited parallelism:

```bash
cat > parallel-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 8
  parallelism: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "Worker $(hostname) starting"
          WORK_TIME=$((RANDOM % 5 + 3))
          echo "Working for $WORK_TIME seconds..."
          sleep $WORK_TIME
          echo "Worker $(hostname) completed"
      restartPolicy: OnFailure
EOF

kubectl apply -f parallel-job.yaml
```

### Watch Parallel Execution

```bash
kubectl get pods -l job-name=parallel-job --watch
```

You'll see 3 Pods running at a time until 8 completions are achieved.

### Check Job Progress

```bash
kubectl get job parallel-job
```

### View All Completed Pods

```bash
kubectl get pods -l job-name=parallel-job
kubectl logs -l job-name=parallel-job | grep completed
```

### Parallel Job Parameters

| Setting | Effect |
|---------|--------|
| `completions: 8, parallelism: 3` | Run 8 total, 3 at a time |
| `completions: 1, parallelism: 1` | One-shot (default) |
| `completions: 10, parallelism: 10` | All 10 run simultaneously |

---

## Part 10: Work Queue Pattern

Jobs can process items from a work queue until empty.

### Create Work Queue Simulation

```bash
cat > workqueue-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: workqueue-job
spec:
  parallelism: 3
  # No completions specified = work queue mode
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "Worker starting on $(hostname)"
          # Simulate processing work items
          ITEMS=$((RANDOM % 3 + 1))
          for i in $(seq 1 $ITEMS); do
            echo "Processing item $i of $ITEMS"
            sleep 2
          done
          echo "Queue empty, worker exiting"
      restartPolicy: OnFailure
EOF

kubectl apply -f workqueue-job.yaml
```

### Watch Work Queue Processing

```bash
kubectl get pods -l job-name=workqueue-job --watch
```

In work queue mode, the job completes when any Pod exits successfully.

### Cleanup Parallel Jobs

```bash
kubectl delete job parallel-job workqueue-job
```

---

## Part 11: Job with Deadline

Set maximum runtime for Jobs.

```bash
cat > deadline-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: deadline-job
spec:
  activeDeadlineSeconds: 30
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Starting long task'; sleep 120; echo 'Done'"]
      restartPolicy: OnFailure
EOF

kubectl apply -f deadline-job.yaml
```

### Watch Job Timeout

```bash
kubectl get job deadline-job --watch
```

After 30 seconds, the job is terminated.

### Check Failure Reason

```bash
kubectl describe job deadline-job | grep -A 5 "Conditions"
```

### Cleanup

```bash
kubectl delete job deadline-job
```

---

## Part 12: CronJobs

CronJobs run Jobs on a schedule.

### Create a CronJob

```bash
cat > simple-cronjob.yaml <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cron
spec:
  schedule: "*/1 * * * *"  # Every minute
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:latest
            command: ["sh", "-c", "echo 'Hello from CronJob at $(date)'"]
          restartPolicy: OnFailure
EOF

kubectl apply -f simple-cronjob.yaml
```

### View CronJob

```bash
kubectl get cronjobs
kubectl describe cronjob hello-cron
```

### Watch Jobs Created by CronJob

```bash
kubectl get jobs --watch
```

Wait a minute and you'll see jobs being created.

### View CronJob History

```bash
kubectl get jobs -l job-name=hello-cron
kubectl get pods -l job-name
```

### Cron Schedule Format

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday = 0)
│ │ │ │ │
* * * * *
```

| Schedule | Meaning |
|----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Every hour |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday |
| `0 0 1 * *` | Monthly on the 1st |

### CronJob Configuration Options

```bash
cat > configured-cronjob.yaml <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: configured-cron
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 60
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: busybox:latest
            command: ["sh", "-c", "echo 'Task running'; sleep 10; echo 'Task done'"]
          restartPolicy: OnFailure
EOF

kubectl apply -f configured-cronjob.yaml
```

### CronJob Options Explained

| Option | Description |
|--------|-------------|
| `concurrencyPolicy` | Allow, Forbid, or Replace concurrent jobs |
| `successfulJobsHistoryLimit` | Number of successful jobs to keep |
| `failedJobsHistoryLimit` | Number of failed jobs to keep |
| `startingDeadlineSeconds` | Deadline for starting if schedule missed |
| `suspend` | Set to true to suspend scheduling |

### Concurrency Policies

| Policy | Behavior |
|--------|----------|
| `Allow` | Multiple jobs can run concurrently (default) |
| `Forbid` | Skip new job if previous still running |
| `Replace` | Cancel current job and start new one |

### Suspend and Resume CronJob

```bash
# Suspend
kubectl patch cronjob hello-cron -p '{"spec":{"suspend":true}}'
kubectl get cronjob hello-cron

# Resume
kubectl patch cronjob hello-cron -p '{"spec":{"suspend":false}}'
```

### Cleanup CronJobs

```bash
kubectl delete cronjob hello-cron configured-cron
```

---

## Exercises

### Exercise 1: Node Monitoring DaemonSet

Create a DaemonSet that monitors node resources:

```bash
cd ~/daemonsets-jobs-lab

cat > monitor-daemon.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - name: monitor
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          while true; do
            echo "=== Node: $(hostname) at $(date) ==="
            echo "Memory:" && cat /proc/meminfo | head -3
            echo "CPU:" && cat /proc/loadavg
            echo "---"
            sleep 30
          done
        resources:
          limits:
            memory: 64Mi
            cpu: 50m
EOF

kubectl apply -f monitor-daemon.yaml

# Verify
kubectl get ds node-monitor
kubectl get pods -l app=node-monitor -o wide
kubectl logs -l app=node-monitor --tail=10
```

Cleanup:

```bash
kubectl delete -f monitor-daemon.yaml
```

### Exercise 2: Batch Processing Job

Create a job that processes multiple items:

```bash
cat > batch-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-processor
spec:
  completions: 5
  parallelism: 2
  template:
    spec:
      containers:
      - name: processor
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          ITEM_ID=$(hostname | cut -d'-' -f3)
          echo "Processing item $ITEM_ID"
          echo "Step 1: Validating..."
          sleep 2
          echo "Step 2: Processing..."
          sleep 3
          echo "Step 3: Completing..."
          sleep 1
          echo "Item $ITEM_ID completed successfully"
      restartPolicy: OnFailure
EOF

kubectl apply -f batch-job.yaml

# Watch progress
kubectl get job batch-processor --watch

# View all completions
kubectl get pods -l job-name=batch-processor
kubectl logs -l job-name=batch-processor | grep completed
```

Cleanup:

```bash
kubectl delete -f batch-job.yaml
```

### Exercise 3: Database Backup CronJob

Create a scheduled backup job:

```bash
cat > backup-cronjob.yaml <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
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
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              echo "Starting backup at $TIMESTAMP"
              echo "Simulating database dump..."
              sleep 5
              echo "Backup completed: backup_$TIMESTAMP.sql"
          restartPolicy: OnFailure
EOF

kubectl apply -f backup-cronjob.yaml

# Watch for jobs
kubectl get cronjob db-backup
kubectl get jobs --watch

# After a few minutes, check history
kubectl get jobs -l job-name
```

Cleanup:

```bash
kubectl delete -f backup-cronjob.yaml
```

---

## Optional Advanced Exercises

### Exercise 4: DaemonSet with Tolerations

Run DaemonSet on all nodes including control-plane:

```bash
cat > toleration-daemon.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: all-nodes-daemon
spec:
  selector:
    matchLabels:
      app: all-nodes
  template:
    metadata:
      labels:
        app: all-nodes
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: daemon
        image: busybox:latest
        command: ["sh", "-c", "while true; do echo 'Running on' $(hostname); sleep 60; done"]
        resources:
          limits:
            memory: 32Mi
            cpu: 25m
EOF

kubectl apply -f toleration-daemon.yaml
kubectl get pods -l app=all-nodes -o wide
```

Cleanup:

```bash
kubectl delete -f toleration-daemon.yaml
```

### Exercise 5: Job with TTL Cleanup

Create a job that auto-deletes after completion:

```bash
cat > ttl-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: ttl-job
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Quick task'; sleep 5; echo 'Done'"]
      restartPolicy: Never
EOF

kubectl apply -f ttl-job.yaml

# Watch job complete and get cleaned up after 60 seconds
kubectl get jobs ttl-job --watch
```

---

## Key Takeaways

### DaemonSets

- **DaemonSets** run one Pod per node (or subset of nodes)
- Use **node selectors** to target specific nodes
- DaemonSets support **rolling updates** like Deployments
- Common use cases: logging, monitoring, networking agents
- Adding/removing node labels dynamically affects Pod placement

### Jobs

- **Jobs** run Pods to completion (not continuously)
- Use `restartPolicy: OnFailure` to retry in same Pod
- Use `restartPolicy: Never` to create new Pods on failure
- **Parallel jobs** process multiple items simultaneously
- **Work queue pattern** runs until first successful exit

### CronJobs

- **CronJobs** create Jobs on a schedule
- Use `concurrencyPolicy` to control overlapping runs
- Set history limits to manage completed jobs
- Can be suspended/resumed without deletion

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl get ds` | List DaemonSets |
| `kubectl describe ds <name>` | DaemonSet details |
| `kubectl rollout status ds <name>` | Watch DaemonSet rollout |
| `kubectl rollout undo ds <name>` | Rollback DaemonSet |
| `kubectl get jobs` | List Jobs |
| `kubectl describe job <name>` | Job details |
| `kubectl logs -l job-name=<name>` | Job pod logs |
| `kubectl get cronjobs` | List CronJobs |
| `kubectl create job <name> --from=cronjob/<cron>` | Manually trigger CronJob |

### DaemonSet Manifest Template

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: my-daemon
spec:
  selector:
    matchLabels:
      app: my-daemon
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: my-daemon
    spec:
      nodeSelector:
        key: value
      containers:
      - name: daemon
        image: my-image:tag
        resources:
          limits:
            memory: 128Mi
            cpu: 100m
      volumes:
      - name: host-data
        hostPath:
          path: /var/log
```

### Job Manifest Template

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 6
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      containers:
      - name: worker
        image: my-image:tag
      restartPolicy: OnFailure
```

### CronJob Manifest Template

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
spec:
  schedule: "0 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 60
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: my-image:tag
          restartPolicy: OnFailure
```

---

## Cleanup (End of Lab)

```bash
# Delete all DaemonSets
kubectl delete ds simple-daemon selective-daemon update-daemon log-collector node-monitor all-nodes-daemon 2>/dev/null || true

# Delete all Jobs
kubectl delete jobs oneshot failing-job failing-job-never parallel-job workqueue-job deadline-job batch-processor ttl-job 2>/dev/null || true

# Delete all CronJobs
kubectl delete cronjob hello-cron configured-cron db-backup 2>/dev/null || true

# Remove node labels
kubectl label nodes kind-cluster-worker workload- 2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/daemonsets-jobs-lab

# Verify cleanup
kubectl get ds
kubectl get jobs
kubectl get cronjobs
```

---

## Troubleshooting Common Issues

### DaemonSet Not Running on All Nodes

```bash
# Check DaemonSet status
kubectl describe ds <name>

# Check for node selector issues
kubectl get ds <name> -o yaml | grep -A 5 nodeSelector

# Check for tolerations (control-plane nodes have taints)
kubectl describe node <node-name> | grep Taints

# Verify nodes match selector
kubectl get nodes --show-labels
```

### Job Never Completes

```bash
# Check job status
kubectl describe job <name>

# Check pod status
kubectl get pods -l job-name=<name>

# Check pod logs
kubectl logs -l job-name=<name>

# Common causes:
# - Container never exits (missing exit command)
# - Exit code non-zero
# - Resource limits exceeded
# - Image pull issues
```

### CronJob Not Triggering

```bash
# Check CronJob status
kubectl describe cronjob <name>

# Verify schedule syntax
kubectl get cronjob <name> -o jsonpath='{.spec.schedule}'

# Check if suspended
kubectl get cronjob <name> -o jsonpath='{.spec.suspend}'

# Check for startingDeadlineSeconds issues
kubectl describe cronjob <name> | grep "Last Schedule"

# View events
kubectl get events --field-selector involvedObject.name=<name>
```

### Too Many Completed Jobs

```bash
# Check history limits
kubectl get cronjob <name> -o yaml | grep -E "History|Limit"

# Manually clean up old jobs
kubectl delete jobs -l job-name=<cronjob-name>

# Set TTL on jobs
# Add ttlSecondsAfterFinished to job template
```

---

## Additional Resources

- [DaemonSets Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Jobs Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJobs Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Running Automated Tasks with CronJob](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/)
- [Parallel Processing using Expansions](https://kubernetes.io/docs/tasks/job/parallel-processing-expansion/)


