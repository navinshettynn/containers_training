# Kubernetes DaemonSets and Jobs – Test Questions

Use these questions to assess participant understanding after completing the DaemonSets and Jobs lab.

---

## Section 1: Multiple Choice

**1. What is the primary purpose of a DaemonSet?**

a) To run multiple replicas of an application  
b) To ensure one Pod runs on each node (or subset of nodes)  
c) To schedule Jobs on a timer  
d) To manage application updates  

---

**2. When should you use a DaemonSet instead of a Deployment?**

a) When you need horizontal scaling  
b) When your application needs multiple replicas per node  
c) When you need exactly one Pod per node for node-level services  
d) When you need zero-downtime updates  

---

**3. What happens when a new node is added to a cluster with an existing DaemonSet?**

a) Nothing, the DaemonSet only manages existing nodes  
b) The DaemonSet controller automatically creates a Pod on the new node  
c) You must manually apply the DaemonSet again  
d) The cluster must be restarted  

---

**4. How do you limit a DaemonSet to run only on specific nodes?**

a) Set the `replicas` field to match the number of target nodes  
b) Use a `nodeSelector` in the Pod spec  
c) Use `targetNodes` in the DaemonSet spec  
d) Create multiple DaemonSets with different names  

---

**5. What is the default update strategy for DaemonSets?**

a) Recreate  
b) OnDelete  
c) RollingUpdate  
d) BlueGreen  

---

**6. What is the primary purpose of a Kubernetes Job?**

a) To run Pods continuously  
b) To run Pods until successful completion  
c) To schedule recurring tasks  
d) To manage long-running services  

---

**7. What does a Job do if a Pod fails with a non-zero exit code?**

a) Marks the job as failed immediately  
b) Retries based on backoffLimit setting  
c) Ignores the failure  
d) Deletes all related Pods  

---

**8. What does `restartPolicy: OnFailure` mean for a Job?**

a) Create a new Pod for each retry  
b) Restart the container within the same Pod  
c) Never restart on failure  
d) Only restart once  

---

**9. What happens when `restartPolicy: Never` is used and a Job Pod fails?**

a) The same Pod is restarted  
b) A new Pod is created for the retry  
c) The job fails immediately  
d) The cluster restarts  

---

**10. In a Job with `completions: 10` and `parallelism: 3`, how many Pods run simultaneously?**

a) 10  
b) 3  
c) 1  
d) 30  

---

**11. What is a CronJob?**

a) A Job that runs on multiple CPUs  
b) A Job that creates other Jobs on a schedule  
c) A Job that monitors CPU usage  
d) A type of DaemonSet  

---

**12. What does `concurrencyPolicy: Forbid` do in a CronJob?**

a) Prevents the CronJob from running  
b) Skips the new job if the previous one is still running  
c) Cancels the current job when a new one starts  
d) Allows multiple jobs to run concurrently  

---

**13. What field controls how long a Job can run before being terminated?**

a) `timeoutSeconds`  
b) `activeDeadlineSeconds`  
c) `maxRuntime`  
d) `deadline`  

---

**14. What does `ttlSecondsAfterFinished` control in a Job?**

a) How long before the job starts  
b) How long to keep the job after completion before auto-deletion  
c) Maximum runtime for the job  
d) Time between retries  

---

**15. Which volume type is commonly used with DaemonSets to access node-level data?**

a) emptyDir  
b) persistentVolumeClaim  
c) hostPath  
d) configMap  

---

**16. What is the "work queue" pattern in Jobs?**

a) Jobs that run sequentially  
b) Jobs with no completions specified that exit when work is done  
c) Jobs that process a fixed number of items  
d) Jobs that never complete  

---

**17. In a DaemonSet, what determines the number of Pods created?**

a) The `replicas` field  
b) The number of nodes matching the selector  
c) The `parallelism` field  
d) The `completions` field  

---

**18. What happens if you remove a label from a node that a DaemonSet's nodeSelector requires?**

a) Nothing changes  
b) The Pod on that node is terminated  
c) The DaemonSet is deleted  
d) A new Pod is created elsewhere  

---

**19. What is `backoffLimit` in a Job specification?**

a) Maximum number of retries before job is marked failed  
b) Delay between retries  
c) Maximum parallel Pods  
d) Number of completions needed  

---

**20. Which field in a CronJob limits how many successful job records are kept?**

a) `historyLimit`  
b) `successfulJobsHistoryLimit`  
c) `keepSuccessful`  
d) `retainJobs`  

---

## Section 2: True or False

**21. DaemonSets create exactly one Pod per node by default.**

☐ True  
☐ False  

---

**22. DaemonSets support rolling updates similar to Deployments.**

☐ True  
☐ False  

---

**23. A Job with `restartPolicy: Always` will run indefinitely.**

☐ True  
☐ False  

---

**24. CronJobs can be suspended without deleting them.**

☐ True  
☐ False  

---

**25. If a node is removed from the cluster, the DaemonSet Pod on it is rescheduled to another node.**

☐ True  
☐ False  

---

**26. Job Pods are automatically deleted immediately after successful completion.**

☐ True  
☐ False  

---

**27. DaemonSets ignore the Kubernetes scheduler and specify nodeName directly.**

☐ True  
☐ False  

---

**28. A CronJob with `concurrencyPolicy: Replace` cancels the running job when a new one is scheduled.**

☐ True  
☐ False  

---

**29. The `OnDelete` update strategy for DaemonSets automatically updates Pods.**

☐ True  
☐ False  

---

**30. Jobs can run multiple Pods in parallel using the `parallelism` field.**

☐ True  
☐ False  

---

## Section 3: Fill in the Blank

**31. Complete the command to view all Pods created by a DaemonSet named `monitoring`:**

```bash
kubectl get pods -l __________ -o wide
```

---

**32. Complete the DaemonSet spec to only run on nodes with label `gpu=true`:**

```yaml
spec:
  template:
    spec:
      __________:
        gpu: "true"
```

---

**33. Complete the Job spec to allow a maximum of 4 retries:**

```yaml
spec:
  __________: 4
```

---

**34. The cron schedule `0 */6 * * *` runs a job every __________ hours.**

---

**35. Complete the command to view the rollout status of a DaemonSet:**

```bash
kubectl rollout __________ ds my-daemon
```

---

**36. In a Job spec, setting __________ to Never creates new Pods for each retry instead of restarting.**

---

**37. Complete the CronJob spec to skip creating new jobs if the previous one is still running:**

```yaml
spec:
  concurrencyPolicy: __________
```

---

**38. Complete the command to manually trigger a job from a CronJob:**

```bash
kubectl create job manual-run --from=__________/my-cronjob
```

---

**39. The __________ update strategy for DaemonSets only updates Pods when they are manually deleted.**

---

**40. In a Job, setting `completions: 5` and `parallelism: 5` runs __________ Pods simultaneously.**

---

## Section 4: Short Answer

**41. Explain the difference between DaemonSets and ReplicaSets. When would you use each?**

---

**42. What are three common use cases for DaemonSets?**

---

**43. Explain the difference between `restartPolicy: OnFailure` and `restartPolicy: Never` in Jobs.**

---

**44. Describe the "parallel fixed completions" job pattern and provide an example use case.**

---

**45. What is the purpose of `minReadySeconds` in a DaemonSet, and why is it important?**

---

**46. How do CronJobs handle missed schedules, and what role does `startingDeadlineSeconds` play?**

---

**47. A DaemonSet is not creating Pods on certain nodes. List the troubleshooting steps you would take.**

---

**48. Explain the work queue pattern for Jobs and when you would use it.**

---

## Section 5: Practical Scenarios

**49. Write a DaemonSet manifest that:**
- Runs a log collector on all nodes
- Uses image `fluentd:latest`
- Mounts `/var/log` from the host
- Has memory limit of 256Mi

---

**50. Write the commands to:**
1. Create a DaemonSet that runs on all nodes
2. Add a label to only the worker node
3. Modify the DaemonSet to only run on labeled nodes
4. Verify the Pod is removed from the control-plane node

---

**51. Write a Job manifest that:**
- Runs 10 completions with 3 parallel Pods
- Uses image `busybox:latest`
- Has a backoff limit of 2
- Auto-deletes after 1 hour

---

**52. Write a CronJob manifest that:**
- Runs daily at 3:00 AM
- Forbids concurrent runs
- Keeps 5 successful job records
- Keeps 2 failed job records

---

**53. A team needs a DaemonSet that only runs on nodes with SSDs. Write the commands to:**
1. Label the appropriate nodes with `storage=ssd`
2. Create a DaemonSet with the correct node selector
3. Verify the DaemonSet is running only on SSD nodes
4. Add the label to another node and verify Pod creation

---

**54. Write the commands to troubleshoot a Job that seems stuck:**
1. Check job status
2. View the pods created by the job
3. Check pod logs
4. Check pod events
5. Delete and recreate if necessary

---

**55. Write a Job manifest for a database migration that:**
- Runs exactly once
- Has a 10-minute deadline
- Retries up to 3 times on failure
- Uses restart policy that creates new Pods on failure

---

**56. Write the commands to:**
1. Create a CronJob that runs every 15 minutes
2. Suspend the CronJob
3. Manually trigger a job from the suspended CronJob
4. Resume the CronJob

---

---

## Answer Key

### Section 1: Multiple Choice

| Q | Answer | Explanation |
|---|--------|-------------|
| 1 | b | DaemonSets ensure one Pod runs on each matching node |
| 2 | c | DaemonSets are for node-level services requiring one Pod per node |
| 3 | b | DaemonSet controller automatically creates Pods on new nodes |
| 4 | b | nodeSelector in the Pod spec limits which nodes run the Pod |
| 5 | c | RollingUpdate is the default strategy for DaemonSets |
| 6 | b | Jobs run Pods until successful completion (exit 0) |
| 7 | b | Jobs retry based on backoffLimit setting |
| 8 | b | OnFailure restarts the container in the same Pod |
| 9 | b | Never creates a new Pod for each retry |
| 10 | b | parallelism controls concurrent Pods (3 in this case) |
| 11 | b | CronJobs create Jobs on a schedule |
| 12 | b | Forbid skips new jobs if previous is still running |
| 13 | b | activeDeadlineSeconds sets maximum runtime |
| 14 | b | ttlSecondsAfterFinished controls auto-cleanup delay |
| 15 | c | hostPath is used to access node filesystems |
| 16 | b | Work queue has no completions and exits when work is done |
| 17 | b | Number of nodes matching the selector determines Pod count |
| 18 | b | Pod is terminated when node no longer matches selector |
| 19 | a | backoffLimit is maximum retries before marking failed |
| 20 | b | successfulJobsHistoryLimit controls kept records |

### Section 2: True or False

| Q | Answer | Explanation |
|---|--------|-------------|
| 21 | True | DaemonSets create exactly one Pod per matching node |
| 22 | True | DaemonSets support RollingUpdate strategy |
| 23 | False | Jobs don't allow restartPolicy: Always (only OnFailure or Never) |
| 24 | True | CronJobs can be suspended with spec.suspend: true |
| 25 | False | DaemonSet Pods are not rescheduled; each node has its own Pod |
| 26 | False | Pods are retained by default for log inspection |
| 27 | True | DaemonSets specify nodeName directly, bypassing the scheduler |
| 28 | True | Replace policy cancels current job for new one |
| 29 | False | OnDelete only updates when Pods are manually deleted |
| 30 | True | parallelism field controls parallel Pod execution |

### Section 3: Fill in the Blank

| Q | Answer |
|---|--------|
| 31 | `app=monitoring` (or the DaemonSet's selector labels) |
| 32 | `nodeSelector` |
| 33 | `backoffLimit` |
| 34 | `6` |
| 35 | `status` |
| 36 | `restartPolicy` |
| 37 | `Forbid` |
| 38 | `cronjob` |
| 39 | `OnDelete` |
| 40 | `5` |

### Section 4: Short Answer

**41.** 
- **DaemonSet**: Ensures exactly one Pod runs on each node (or subset). Number of Pods equals number of matching nodes. Used for node-level services.
- **ReplicaSet**: Runs a specified number of Pod replicas, distributed across nodes by the scheduler. Used for application workloads.

Use DaemonSet for: log collectors, monitoring agents, network plugins.
Use ReplicaSet (via Deployment) for: web servers, APIs, microservices.

**42.** Common DaemonSet use cases:
1. **Log collection** - Fluentd, Filebeat, Logstash agents
2. **Node monitoring** - Prometheus Node Exporter, Datadog agent
3. **Networking** - CNI plugins (Calico, Weave), kube-proxy
4. **Storage** - CSI node drivers
5. **Security** - Intrusion detection, antivirus agents

**43.** 
- **OnFailure**: Restarts the failed container within the same Pod. Pod stays on the same node. Good for transient failures. Uses less resources (fewer Pods created).
- **Never**: Creates a new Pod for each retry. Old failed Pods remain for debugging. Can schedule on different nodes. Creates "junk" Pods if not cleaned up.

Use OnFailure for most cases; use Never when you need to preserve failed Pod state for debugging.

**44.** Parallel fixed completions pattern:
- Set `completions` to total work items
- Set `parallelism` to concurrent workers
- Each Pod processes one work item
- Job completes when all completions succeed

Example: Processing 100 images with 10 parallel workers (`completions: 100, parallelism: 10`). Each Pod processes one image, 10 run at a time, job completes after 100 successful completions.

**45.** `minReadySeconds` in DaemonSets:
- Specifies minimum time a Pod must be ready before the rolling update proceeds
- Prevents cascading failures from bad updates
- Allows time for latent issues to surface
- Important for stability during updates
- Recommended: 30-60 seconds for production

**46.** CronJob missed schedule handling:
- If schedule is missed (e.g., cluster down), CronJob decides whether to run
- `startingDeadlineSeconds` defines the window for starting a missed job
- If current time exceeds schedule time + startingDeadlineSeconds, job is skipped
- If >100 schedules missed in the deadline window, job stops scheduling
- Set startingDeadlineSeconds to allow reasonable catch-up time

**47.** DaemonSet troubleshooting steps:
1. Check DaemonSet status: `kubectl describe ds <name>`
2. Verify node labels match selector: `kubectl get nodes --show-labels`
3. Check for node taints: `kubectl describe node <name> | grep Taints`
4. Verify Pod tolerations if needed
5. Check resource constraints (CPU/memory limits)
6. Check events for scheduling failures
7. Verify image can be pulled on all nodes

**48.** Work queue pattern:
- `completions` is not set (or set to null)
- `parallelism` is set to number of workers
- Workers process items from an external queue
- Job completes when any Pod exits successfully
- Assumes exit signals "queue is empty"

Use for: Processing messages from a queue, batch jobs with dynamic work items, when work count isn't known in advance.

### Section 5: Practical Scenarios

**49.**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
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
      - name: fluentd
        image: fluentd:latest
        resources:
          limits:
            memory: 256Mi
          requests:
            memory: 128Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

**50.**
```bash
# 1. Create DaemonSet
kubectl create -f daemonset.yaml
# or
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: my-daemon
spec:
  selector:
    matchLabels:
      app: my-daemon
  template:
    metadata:
      labels:
        app: my-daemon
    spec:
      containers:
      - name: daemon
        image: busybox
        command: ["sleep", "infinity"]
EOF

# 2. Label worker node
kubectl label nodes <worker-node> role=worker

# 3. Patch DaemonSet with nodeSelector
kubectl patch ds my-daemon -p '{"spec":{"template":{"spec":{"nodeSelector":{"role":"worker"}}}}}'

# 4. Verify
kubectl get pods -l app=my-daemon -o wide
```

**51.**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 10
  parallelism: 3
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["sh", "-c", "echo 'Processing item'; sleep 5; echo 'Done'"]
      restartPolicy: OnFailure
```

**52.**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-image:latest
            command: ["backup.sh"]
          restartPolicy: OnFailure
```

**53.**
```bash
# 1. Label nodes
kubectl label nodes node1 node2 storage=ssd

# 2. Create DaemonSet
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-daemon
spec:
  selector:
    matchLabels:
      app: ssd-daemon
  template:
    metadata:
      labels:
        app: ssd-daemon
    spec:
      nodeSelector:
        storage: ssd
      containers:
      - name: daemon
        image: busybox
        command: ["sleep", "infinity"]
EOF

# 3. Verify
kubectl get pods -l app=ssd-daemon -o wide
kubectl get nodes -l storage=ssd

# 4. Add label to another node
kubectl label nodes node3 storage=ssd
kubectl get pods -l app=ssd-daemon -o wide
```

**54.**
```bash
# 1. Check job status
kubectl get job <job-name>
kubectl describe job <job-name>

# 2. View pods
kubectl get pods -l job-name=<job-name>

# 3. Check pod logs
kubectl logs -l job-name=<job-name>
# For failed pods:
kubectl logs -l job-name=<job-name> --previous

# 4. Check events
kubectl describe pods -l job-name=<job-name> | grep -A 10 Events
kubectl get events --field-selector involvedObject.name=<pod-name>

# 5. Delete and recreate
kubectl delete job <job-name>
kubectl apply -f job.yaml
```

**55.**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  activeDeadlineSeconds: 600
  template:
    spec:
      containers:
      - name: migration
        image: migration-image:latest
        command: ["migrate.sh"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
      restartPolicy: Never
```

**56.**
```bash
# 1. Create CronJob running every 15 minutes
kubectl create -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: every-15-min
spec:
  schedule: "*/15 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: busybox
            command: ["echo", "Running task"]
          restartPolicy: OnFailure
EOF

# 2. Suspend
kubectl patch cronjob every-15-min -p '{"spec":{"suspend":true}}'

# 3. Manually trigger
kubectl create job manual-trigger --from=cronjob/every-15-min

# 4. Resume
kubectl patch cronjob every-15-min -p '{"spec":{"suspend":false}}'
```

---

## Scoring Guide

| Score | Level |
|-------|-------|
| 50-56 | Expert – Ready for advanced Kubernetes workload patterns |
| 42-49 | Proficient – Solid understanding, minor gaps |
| 34-41 | Intermediate – Review DaemonSet and Job concepts |
| 25-33 | Beginner – Review core workload concepts |
| 0-24 | Needs Review – Retake the lab exercises |


