# Kubernetes Pods – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. You have completed the kubectl commands lab (or are familiar with basic kubectl usage)

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

### Create a Lab Directory

```bash
mkdir -p ~/pods-lab
cd ~/pods-lab
```

---

## Learning Objectives

- Understand what a **Pod** is and why it's the basic unit in Kubernetes
- Learn when to use **single-container** vs **multi-container** Pods
- Create Pods using both **imperative** and **declarative** methods
- Write and understand **Pod manifests** (YAML)
- **Inspect**, **debug**, and **delete** Pods
- Implement **health checks** (liveness, readiness, startup probes)
- Configure **resource requests and limits**
- Use **volumes** to persist data in Pods

### Intermediate Objectives (Optional)

- Create **multi-container Pods** with shared volumes
- Configure **advanced probe options**
- Understand Pod **lifecycle** and **termination**
- Work with different **volume types**

---

## What is a Pod?

A Pod is the **smallest deployable unit** in Kubernetes. Key characteristics:

| Feature | Description |
|---------|-------------|
| **Atomic unit** | One or more containers scheduled together |
| **Shared network** | All containers share the same IP address and port space |
| **Shared storage** | Containers can share volumes |
| **Co-located** | All containers run on the same node |
| **Lifecycle** | Containers in a Pod start and stop together |

### When to Use Multi-Container Pods

Ask yourself: **"Will these containers work correctly if they land on different machines?"**

- If **No** → Put them in the same Pod
- If **Yes** → Use separate Pods

**Good examples of multi-container Pods:**
- Web server + log shipper (sidecar pattern)
- App + file sync container
- Main app + proxy/ambassador

**Bad examples (antipatterns):**
- WordPress + MySQL (can communicate over network)
- Frontend + Backend (scale independently)

---

## Part 1: Creating Pods (Imperative Method)

The simplest way to create a Pod is using `kubectl run`.

### Create a Simple Pod

```bash
kubectl run my-nginx --image=nginx:alpine
```

### Check Pod Status

```bash
kubectl get pods
```

You might see:

```
NAME       READY   STATUS    RESTARTS   AGE
my-nginx   1/1     Running   0          10s
```

### Common Pod Statuses

| Status | Description |
|--------|-------------|
| `Pending` | Pod accepted but not yet scheduled or pulling images |
| `Running` | Pod is running on a node |
| `Succeeded` | All containers completed successfully |
| `Failed` | At least one container failed |
| `CrashLoopBackOff` | Container keeps crashing and restarting |
| `ImagePullBackOff` | Cannot pull the container image |

### Get More Details

```bash
# Wide output with node and IP info
kubectl get pods -o wide

# Detailed information
kubectl describe pod my-nginx
```

### Delete the Pod

```bash
kubectl delete pod my-nginx
```

---

## Part 2: Creating Pods (Declarative Method)

The recommended approach is to define Pods in YAML manifests.

### Understanding the Pod Manifest Structure

A Pod manifest has these key sections:

```yaml
apiVersion: v1          # API version
kind: Pod               # Resource type
metadata:               # Pod metadata (name, labels, etc.)
  name: pod-name
spec:                   # Pod specification
  containers:           # List of containers
  - name: container-name
    image: image:tag
```

### Create a Basic Pod Manifest

```bash
cat > basic-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: basic-nginx
  labels:
    app: web
    environment: lab
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
      name: http
      protocol: TCP
EOF
```

### Apply the Manifest

```bash
kubectl apply -f basic-pod.yaml
```

### Verify the Pod is Running

```bash
kubectl get pods basic-nginx
kubectl get pods basic-nginx -o wide
```

### View the Full Pod Specification

```bash
kubectl get pod basic-nginx -o yaml
```

### Cleanup

```bash
kubectl delete -f basic-pod.yaml
```

---

## Part 3: Pod Details and Inspection

### Create a Pod for Inspection

```bash
cat > inspect-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: inspect-me
  labels:
    app: demo
    version: "1.0"
  annotations:
    description: "A pod for learning inspection commands"
    owner: "lab-user"
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sh", "-c", "echo 'Pod is running!' && sleep 3600"]
EOF

kubectl apply -f inspect-pod.yaml
```

### Basic Pod Information

```bash
kubectl get pod inspect-me
```

### Extended Information

```bash
kubectl get pod inspect-me -o wide
```

This shows:
- Node where the Pod is running
- Pod IP address
- Nominated node (if any)
- Readiness gates

### Detailed Description

```bash
kubectl describe pod inspect-me
```

Key sections in the output:

| Section | Information |
|---------|-------------|
| **Name/Namespace** | Pod identity |
| **Node** | Where the Pod is running |
| **Start Time** | When the Pod started |
| **Labels/Annotations** | Metadata attached to the Pod |
| **Status** | Current Pod phase |
| **IP** | Pod's cluster IP address |
| **Containers** | Container details (image, state, ports) |
| **Conditions** | Pod conditions (Initialized, Ready, etc.) |
| **Events** | Recent events related to this Pod |

### Get Specific Fields with JSONPath

```bash
# Get Pod IP
kubectl get pod inspect-me -o jsonpath='{.status.podIP}'

# Get container image
kubectl get pod inspect-me -o jsonpath='{.spec.containers[0].image}'

# Get node name
kubectl get pod inspect-me -o jsonpath='{.spec.nodeName}'

# Get Pod phase
kubectl get pod inspect-me -o jsonpath='{.status.phase}'
```

### View Pod Events Only

```bash
kubectl get events --field-selector involvedObject.name=inspect-me
```

---

## Part 4: Accessing Pods

### View Container Logs

```bash
kubectl logs inspect-me
```

Output:

```
Pod is running!
```

### Stream Logs in Real-Time

First, create a Pod that generates continuous logs:

```bash
cat > logging-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: logger
spec:
  containers:
  - name: logger
    image: busybox:latest
    command: ["sh", "-c", "while true; do echo \"[$(date)] Hello from logger pod\"; sleep 5; done"]
EOF

kubectl apply -f logging-pod.yaml
```

Wait for it to start, then stream logs:

```bash
kubectl logs logger -f
```

Press `Ctrl+C` to stop streaming.

### View Previous Container Logs

If a container restarts, view logs from the previous instance:

```bash
kubectl logs logger --previous
```

(This will show an error if the container hasn't restarted)

### Execute Commands in a Container

```bash
# Run a single command
kubectl exec inspect-me -- hostname

# Run multiple commands
kubectl exec inspect-me -- sh -c "echo 'Hello' && whoami && pwd"

# Get an interactive shell
kubectl exec -it inspect-me -- sh
```

Inside the shell:

```sh
# Check environment variables
env

# Check network configuration
ip addr
cat /etc/resolv.conf

# Check filesystem
ls -la /

# Exit the shell
exit
```

### Copy Files To/From Pods

Copy a file from the Pod:

```bash
kubectl exec inspect-me -- sh -c "echo 'Data from pod' > /tmp/data.txt"
kubectl cp inspect-me:/tmp/data.txt ./data-from-pod.txt
cat ./data-from-pod.txt
```

Copy a file to the Pod:

```bash
echo "Data from host" > ./data-from-host.txt
kubectl cp ./data-from-host.txt inspect-me:/tmp/data-from-host.txt
kubectl exec inspect-me -- cat /tmp/data-from-host.txt
```

### Port Forwarding

Create an nginx Pod and forward its port:

```bash
cat > web-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-server
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

kubectl apply -f web-pod.yaml
kubectl wait --for=condition=Ready pod/web-server
```

Forward local port 8080 to Pod port 80:

```bash
kubectl port-forward web-server 8080:80 &
```

Test the connection:

```bash
curl localhost:8080
```

Stop port forwarding:

```bash
pkill -f "port-forward web-server"
```

---

## Part 5: Deleting Pods

### Delete by Name

```bash
kubectl delete pod web-server
```

### Delete Using Manifest File

```bash
kubectl delete -f logging-pod.yaml
```

### Delete Multiple Pods

```bash
kubectl delete pods inspect-me logger --ignore-not-found
```

### Delete All Pods in Namespace

```bash
# Be careful with this command!
kubectl delete pods --all
```

### Understanding Pod Termination

When you delete a Pod:

1. Pod enters `Terminating` state
2. Kubernetes sends **SIGTERM** to containers
3. Containers have a **grace period** (default 30 seconds) to shut down
4. If containers don't stop, Kubernetes sends **SIGKILL**

### Force Delete (Immediate)

```bash
kubectl delete pod <pod-name> --grace-period=0 --force
```

**Warning**: Use this only when necessary, as it doesn't allow graceful shutdown.

---

## Part 6: Health Checks (Probes)

Health checks ensure your application is running correctly. Kubernetes supports three types of probes.

### Types of Probes

| Probe Type | Purpose | Action on Failure |
|------------|---------|-------------------|
| **Liveness** | Is the container alive? | Restart container |
| **Readiness** | Is the container ready to serve traffic? | Remove from service endpoints |
| **Startup** | Has the container started successfully? | Delay liveness/readiness checks |

### Probe Methods

| Method | Description |
|--------|-------------|
| `httpGet` | HTTP GET request to a path |
| `tcpSocket` | TCP connection to a port |
| `exec` | Execute a command in the container |

### Create a Pod with Liveness Probe

```bash
cat > liveness-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 3
EOF

kubectl apply -f liveness-pod.yaml
```

### Probe Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `initialDelaySeconds` | Seconds before first probe | 0 |
| `periodSeconds` | How often to probe | 10 |
| `timeoutSeconds` | Probe timeout | 1 |
| `successThreshold` | Successes to be considered healthy | 1 |
| `failureThreshold` | Failures before taking action | 3 |

### View Probe Status

```bash
kubectl describe pod liveness-demo | grep -A 10 "Liveness"
```

### Create a Pod with Readiness Probe

```bash
cat > readiness-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 1
      failureThreshold: 3
EOF

kubectl apply -f readiness-pod.yaml
```

### Watch Pod Become Ready

```bash
kubectl get pods readiness-demo --watch
```

The READY column shows `0/1` until the readiness probe passes, then `1/1`.

### Create a Pod with Startup Probe

Startup probes are useful for slow-starting applications:

```bash
cat > startup-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
EOF

kubectl apply -f startup-pod.yaml
```

The startup probe allows up to 30 × 10 = 300 seconds for the container to start.

### Demonstrate Liveness Probe Failure

Create a Pod that will fail its liveness check:

```bash
cat > failing-liveness.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: failing-liveness
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600"]
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
EOF

kubectl apply -f failing-liveness.yaml
```

Watch the Pod restart after the probe fails:

```bash
kubectl get pod failing-liveness --watch
```

After ~35 seconds, the `/tmp/healthy` file is removed, the probe fails, and the container restarts. The RESTARTS column will increment.

View the events:

```bash
kubectl describe pod failing-liveness | grep -A 20 "Events"
```

You'll see events like:
- `Unhealthy: Liveness probe failed`
- `Killing: Container app failed liveness probe, will be restarted`

### Cleanup Probes Section

```bash
kubectl delete pods liveness-demo readiness-demo startup-demo failing-liveness
```

---

## Part 7: Resource Management

Kubernetes allows you to specify resource **requests** (minimum) and **limits** (maximum) for containers.

### Resource Types

| Resource | Unit | Example |
|----------|------|---------|
| CPU | millicores (m) or cores | `100m` = 0.1 core, `1` = 1 core |
| Memory | bytes with suffix | `128Mi`, `1Gi`, `512M` |

### Memory Units

| Suffix | Meaning | Base |
|--------|---------|------|
| `Ki`, `Mi`, `Gi`, `Ti` | Kibibyte, Mebibyte, etc. | Power of 2 (1Ki = 1024) |
| `K`, `M`, `G`, `T` | Kilobyte, Megabyte, etc. | Power of 10 (1K = 1000) |

**Important**: `128Mi` (mebibytes) ≠ `128M` (megabytes). Use `Mi`, `Gi` for consistency.

### Create a Pod with Resource Requests

```bash
cat > resources-request.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: resource-request-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl apply -f resources-request.yaml
```

### View Resource Requests

```bash
kubectl describe pod resource-request-demo | grep -A 5 "Requests"
```

### Create a Pod with Resource Limits

```bash
cat > resources-limit.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: resource-limit-demo
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF

kubectl apply -f resources-limit.yaml
```

### View Resource Configuration

```bash
kubectl describe pod resource-limit-demo | grep -A 10 "Limits\|Requests"
```

### Requests vs Limits

| Aspect | Requests | Limits |
|--------|----------|--------|
| Purpose | Minimum guaranteed resources | Maximum allowed resources |
| Scheduling | Used to find a suitable node | Not used for scheduling |
| CPU behavior | Gets at least this amount | Cannot exceed this amount |
| Memory behavior | Gets at least this amount | OOMKilled if exceeded |

### Demonstrate Memory Limit

Create a Pod that tries to exceed its memory limit:

```bash
cat > memory-stress.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "200M", "--vm-hang", "1"]
    resources:
      limits:
        memory: "100Mi"
EOF

kubectl apply -f memory-stress.yaml
```

Watch the Pod get OOMKilled:

```bash
kubectl get pod memory-stress --watch
```

The Pod will show `OOMKilled` status and restart.

```bash
kubectl describe pod memory-stress | grep -A 5 "Last State"
```

### View Node Resource Usage

```bash
kubectl top nodes
kubectl top pods
```

### Cleanup Resources Section

```bash
kubectl delete pods resource-request-demo resource-limit-demo memory-stress
```

---

## Part 8: Volumes in Pods

Volumes allow data to persist beyond container restarts and enable data sharing between containers.

### Volume Types

| Type | Description | Persistence |
|------|-------------|-------------|
| `emptyDir` | Empty directory on the node | Deleted with Pod |
| `hostPath` | Path on the host node | Persists on node |
| `configMap` | Configuration data | Managed by K8s |
| `secret` | Sensitive data | Managed by K8s |
| `persistentVolumeClaim` | External storage | Independent of Pod |

### Create a Pod with emptyDir Volume

`emptyDir` is useful for scratch space, caching, and sharing data between containers:

```bash
cat > emptydir-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
spec:
  volumes:
  - name: shared-data
    emptyDir: {}
  containers:
  - name: writer
    image: busybox:latest
    command: ["sh", "-c", "while true; do date >> /data/log.txt; sleep 5; done"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox:latest
    command: ["sh", "-c", "tail -f /data/log.txt"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
EOF

kubectl apply -f emptydir-pod.yaml
```

### Verify Both Containers are Running

```bash
kubectl get pod emptydir-demo
```

The READY column should show `2/2`.

### View Logs from Each Container

```bash
# Writer container (no continuous output to stdout)
kubectl logs emptydir-demo -c writer

# Reader container (shows the shared log file)
kubectl logs emptydir-demo -c reader
```

### Check the Shared Data

```bash
kubectl exec emptydir-demo -c writer -- cat /data/log.txt
kubectl exec emptydir-demo -c reader -- cat /data/log.txt
```

Both containers see the same data!

### Create a Pod with hostPath Volume

`hostPath` mounts a file or directory from the host node:

```bash
cat > hostpath-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
spec:
  volumes:
  - name: host-data
    hostPath:
      path: /tmp/k8s-lab-data
      type: DirectoryOrCreate
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "echo 'Hello from Pod' > /host-data/hello.txt && sleep 3600"]
    volumeMounts:
    - name: host-data
      mountPath: /host-data
EOF

kubectl apply -f hostpath-pod.yaml
```

### Verify hostPath Volume

```bash
# Check data in the container
kubectl exec hostpath-demo -- cat /host-data/hello.txt

# Check which node the pod is running on
kubectl get pod hostpath-demo -o jsonpath='{.spec.nodeName}'
```

**Note**: In KIND, you would need to exec into the Docker container running the node to see the hostPath directory.

### emptyDir with Memory Backing

For high-performance temporary storage:

```bash
cat > emptydir-memory.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: memory-backed
spec:
  volumes:
  - name: cache
    emptyDir:
      medium: Memory
      sizeLimit: 100Mi
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
EOF

kubectl apply -f emptydir-memory.yaml
```

Verify the mount:

```bash
kubectl exec memory-backed -- df -h /cache
```

You'll see it's mounted as `tmpfs` (RAM-based filesystem).

### Cleanup Volumes Section

```bash
kubectl delete pods emptydir-demo hostpath-demo memory-backed
```

---

## Part 9: Multi-Container Pod Patterns

### Sidecar Pattern

A sidecar container extends the main container's functionality:

```bash
cat > sidecar-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
spec:
  volumes:
  - name: html
    emptyDir: {}
  containers:
  # Main container - serves web content
  - name: web-server
    image: nginx:alpine
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  # Sidecar container - generates content
  - name: content-generator
    image: busybox:latest
    command: ["sh", "-c", "while true; do echo '<h1>Generated at '$(date)'</h1>' > /html/index.html; sleep 10; done"]
    volumeMounts:
    - name: html
      mountPath: /html
EOF

kubectl apply -f sidecar-pod.yaml
kubectl wait --for=condition=Ready pod/sidecar-demo
```

### Test the Sidecar Pattern

```bash
# Port forward to the web server
kubectl port-forward sidecar-demo 8080:80 &
sleep 2

# View the generated content
curl localhost:8080

# Wait and view again (content changes every 10 seconds)
sleep 10
curl localhost:8080

# Stop port forwarding
pkill -f "port-forward sidecar-demo"
```

### Ambassador Pattern

An ambassador container proxies network connections:

```bash
cat > ambassador-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-demo
spec:
  containers:
  # Main application
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "while true; do wget -qO- localhost:8080 2>/dev/null || echo 'Waiting...'; sleep 5; done"]
  # Ambassador - simple proxy example
  - name: ambassador
    image: nginx:alpine
EOF

kubectl apply -f ambassador-pod.yaml
```

### View Multi-Container Logs

```bash
# Logs from specific container
kubectl logs ambassador-demo -c app
kubectl logs ambassador-demo -c ambassador

# Logs from all containers
kubectl logs ambassador-demo --all-containers
```

### Execute in Specific Container

```bash
kubectl exec -it ambassador-demo -c app -- sh
exit

kubectl exec -it ambassador-demo -c ambassador -- sh
exit
```

### Cleanup Multi-Container Section

```bash
kubectl delete pods sidecar-demo ambassador-demo
```

---

## Exercises

### Exercise 1: Basic Pod Creation

Create a Pod running Redis:

```bash
# Create the manifest
cat > redis-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: my-redis
  labels:
    app: cache
    tier: backend
spec:
  containers:
  - name: redis
    image: redis:alpine
    ports:
    - containerPort: 6379
EOF

# Apply it
kubectl apply -f redis-pod.yaml

# Verify it's running
kubectl get pod my-redis -o wide

# Test Redis connectivity
kubectl exec -it my-redis -- redis-cli ping
```

Expected output: `PONG`

Cleanup:

```bash
kubectl delete -f redis-pod.yaml
```

### Exercise 2: Health Checks Implementation

Create a web server with complete health check configuration:

```bash
cat > healthy-web.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: healthy-web
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 10
      periodSeconds: 3
EOF

kubectl apply -f healthy-web.yaml
```

Observe the Pod becoming ready:

```bash
kubectl get pod healthy-web --watch
```

Describe to see probe configuration:

```bash
kubectl describe pod healthy-web
```

Cleanup:

```bash
kubectl delete -f healthy-web.yaml
```

### Exercise 3: Resource Management

Create a Pod with resource constraints and verify them:

```bash
cat > constrained-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: constrained-app
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "50m"
        memory: "32Mi"
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl apply -f constrained-pod.yaml
```

Verify resource configuration:

```bash
kubectl describe pod constrained-app | grep -A 6 "Limits\|Requests"
```

Check actual usage:

```bash
kubectl top pod constrained-app
```

Cleanup:

```bash
kubectl delete -f constrained-pod.yaml
```

### Exercise 4: Data Sharing Between Containers

Create a Pod where one container writes data and another reads it:

```bash
cat > data-sharing.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: data-sharing
spec:
  volumes:
  - name: shared
    emptyDir: {}
  containers:
  - name: producer
    image: busybox:latest
    command: ["sh", "-c", "for i in 1 2 3 4 5; do echo \"Message $i at $(date)\" >> /shared/messages.txt; sleep 2; done; sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: consumer
    image: busybox:latest
    command: ["sh", "-c", "sleep 15; cat /shared/messages.txt; sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
EOF

kubectl apply -f data-sharing.yaml
```

Wait for messages to be written, then check:

```bash
sleep 15
kubectl logs data-sharing -c consumer
```

Verify from both containers:

```bash
kubectl exec data-sharing -c producer -- cat /shared/messages.txt
kubectl exec data-sharing -c consumer -- cat /shared/messages.txt
```

Cleanup:

```bash
kubectl delete -f data-sharing.yaml
```

---

## Optional Advanced Exercises

### Exercise 5: Debugging a Failing Pod

Create a Pod with an intentional error:

```bash
cat > broken-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
spec:
  containers:
  - name: app
    image: nginx:nonexistent-tag
EOF

kubectl apply -f broken-pod.yaml
```

Debug the issue:

```bash
# Check status
kubectl get pod broken-app

# Describe for details
kubectl describe pod broken-app

# Check events
kubectl get events --field-selector involvedObject.name=broken-app
```

You should see `ImagePullBackOff` or `ErrImagePull` errors.

Fix the Pod:

```bash
kubectl delete pod broken-app

cat > broken-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF

kubectl apply -f broken-pod.yaml
kubectl get pod broken-app
```

Cleanup:

```bash
kubectl delete -f broken-pod.yaml
```

### Exercise 6: Complete Application Pod

Create a Pod with all features combined:

```bash
cat > complete-app.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: complete-app
  labels:
    app: demo
    version: "1.0"
  annotations:
    description: "A complete demo pod with all features"
spec:
  volumes:
  - name: cache
    emptyDir: {}
  - name: config
    emptyDir: {}
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
      name: http
    resources:
      requests:
        cpu: "50m"
        memory: "32Mi"
      limits:
        cpu: "100m"
        memory: "64Mi"
    volumeMounts:
    - name: cache
      mountPath: /cache
    - name: config
      mountPath: /config
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
  - name: sidecar
    image: busybox:latest
    command: ["sh", "-c", "while true; do echo 'Sidecar running...' >> /config/status.log; sleep 30; done"]
    resources:
      requests:
        cpu: "10m"
        memory: "8Mi"
      limits:
        cpu: "20m"
        memory: "16Mi"
    volumeMounts:
    - name: config
      mountPath: /config
EOF

kubectl apply -f complete-app.yaml
```

Explore the Pod:

```bash
# Check status
kubectl get pod complete-app

# Detailed info
kubectl describe pod complete-app

# Access web server
kubectl port-forward complete-app 8080:80 &
sleep 2
curl localhost:8080
pkill -f "port-forward complete-app"

# Check sidecar status
kubectl exec complete-app -c app -- cat /config/status.log
```

Cleanup:

```bash
kubectl delete -f complete-app.yaml
```

---

## Key Takeaways

- **Pods** are the smallest deployable unit in Kubernetes, not containers
- All containers in a Pod share **network namespace** (same IP) and can share **volumes**
- Use **declarative YAML manifests** instead of imperative commands for production
- **Liveness probes** determine if a container needs to be restarted
- **Readiness probes** determine if a container can receive traffic
- **Resource requests** guarantee minimum resources; **limits** cap maximum usage
- **Volumes** enable data persistence and sharing between containers
- Multi-container patterns include **sidecar**, **ambassador**, and **adapter**

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl run <name> --image=<image>` | Create a Pod imperatively |
| `kubectl apply -f <file>` | Create/update Pod from manifest |
| `kubectl get pods` | List Pods |
| `kubectl get pod <name> -o wide` | Pod with extra details |
| `kubectl get pod <name> -o yaml` | Full Pod YAML |
| `kubectl describe pod <name>` | Detailed Pod information |
| `kubectl logs <pod>` | View container logs |
| `kubectl logs <pod> -c <container>` | Logs from specific container |
| `kubectl logs <pod> -f` | Stream logs |
| `kubectl exec <pod> -- <command>` | Execute command in container |
| `kubectl exec -it <pod> -- sh` | Interactive shell |
| `kubectl cp <pod>:<path> <local-path>` | Copy from container |
| `kubectl port-forward <pod> <local>:<container>` | Forward ports |
| `kubectl delete pod <name>` | Delete a Pod |
| `kubectl delete -f <file>` | Delete from manifest |
| `kubectl top pod <name>` | Show resource usage |

### Pod Manifest Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-name
  labels:
    key: value
spec:
  volumes:
  - name: volume-name
    emptyDir: {}
  containers:
  - name: container-name
    image: image:tag
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
    volumeMounts:
    - name: volume-name
      mountPath: /path
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

---

## Cleanup (End of Lab)

```bash
# Delete all pods created in this lab
kubectl delete pods \
  my-nginx basic-nginx inspect-me logger web-server \
  liveness-demo readiness-demo startup-demo failing-liveness \
  resource-request-demo resource-limit-demo memory-stress \
  emptydir-demo hostpath-demo memory-backed \
  sidecar-demo ambassador-demo \
  my-redis healthy-web constrained-app data-sharing \
  broken-app complete-app \
  2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/pods-lab

# Verify cleanup
kubectl get pods
```

---

## Troubleshooting Common Issues

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name>

# Common causes:
# - Insufficient resources on nodes
# - Node selector/affinity not matched
# - PersistentVolumeClaim not bound
```

### Pod in CrashLoopBackOff

```bash
# Check logs from crashed container
kubectl logs <pod-name> --previous

# Check describe for exit code
kubectl describe pod <pod-name>

# Common causes:
# - Application error
# - Missing configuration
# - Failed health checks
```

### ImagePullBackOff

```bash
# Check events
kubectl describe pod <pod-name>

# Common causes:
# - Image doesn't exist
# - Typo in image name
# - Private registry without credentials
# - Network issues
```

### Container OOMKilled

```bash
# Check describe for last state
kubectl describe pod <pod-name>

# Solution: Increase memory limits
# Or fix application memory leak
```

---

## Additional Resources

- [Kubernetes Pods Documentation](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Resource Management for Pods](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)

