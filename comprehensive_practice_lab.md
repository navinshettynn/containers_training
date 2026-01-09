# Comprehensive Practice Lab: CloudMart Microservices Platform

This lab integrates concepts from **Docker** (images, volumes, networks, registries) and **Kubernetes** (Pods, Deployments, Services, ConfigMaps, Secrets, DaemonSets, Jobs) into a single scenario-based project.

You will build and deploy **CloudMart**, a simplified e-commerce platform consisting of multiple microservices.

---

## Scenario Overview

**CloudMart** consists of the following components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Redis Database** | Redis | Session data and caching with persistence and password protection |
| **Inventory API** | Custom Python App | Backend API providing product data |
| **Storefront** | Nginx | Frontend web server exposed to users |
| **Node Monitor** | DaemonSet | Background agent running on every node for health checks |
| **Nightly Report** | CronJob | Scheduled task to generate sales reports |
| **DB Migration** | Job | One-time database initialization |

---

## Prerequisites

- Ubuntu VM with Docker and kubectl installed
- KIND cluster running (created via `install_kind.sh`)
- Basic familiarity with terminal commands
- **Direct terminal access** to the VM (SSH into the VM first, then run commands directly)

**Verify your cluster is ready:**
```bash
kubectl get nodes
```

Expected output:
```
NAME                         STATUS   ROLES           AGE   VERSION
kind-cluster-control-plane   Ready    control-plane   ...   v1.x.x
kind-cluster-worker          Ready    <none>          ...   v1.x.x
```

---

## Phase 1: Docker Fundamentals Review

In this phase, we will review Docker concepts: building images, working with volumes, and understanding container registries.

### Step 1: Create Lab Directory

```bash
mkdir -p ~/cloudmart
cd ~/cloudmart
```

### Step 2: Build a Custom Application Image

We'll create a simple Python API and containerize it.

```bash
mkdir -p ~/cloudmart/inventory-api
cd ~/cloudmart/inventory-api

# 1. Create the application code
cat > app.py <<'EOF'
from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route('/')
def hello():
    redis_host = os.environ.get('REDIS_HOST', 'not-configured')
    return jsonify({
        "service": "Inventory API",
        "hostname": socket.gethostname(),
        "redis_host": redis_host,
        "environment": os.environ.get('APP_ENV', 'development')
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
EOF

# 2. Create requirements.txt
echo "flask" > requirements.txt

# 3. Create Dockerfile
cat > Dockerfile <<'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
EOF
```

### Step 3: Build the Docker Image

```bash
# Build the image
docker build -t cloudmart-api:v1 .

# Verify the image was created
docker images | grep cloudmart
```

### Step 4: Test the Image Locally with Docker

```bash
# Run the container
docker run -d --name api-test -p 8080:5000 \
  -e REDIS_HOST=test-redis \
  -e APP_ENV=docker-test \
  cloudmart-api:v1

# Test it
curl http://localhost:8080/
curl http://localhost:8080/health

# View logs
docker logs api-test

# Cleanup
docker rm -f api-test
```

### Step 5: Load Image into KIND Cluster

> **Important KIND Concept:** KIND nodes are Docker containers. They cannot access `localhost:5000` on your host. Instead, we use `kind load` to copy images directly into KIND nodes.

```bash
# Load the custom image into KIND cluster
kind load docker-image cloudmart-api:v1 --name kind-cluster

# Verify the image is available in KIND nodes
docker exec kind-cluster-worker crictl images | grep cloudmart
```

### Step 6: Test Database Persistence with Docker Volumes

Before deploying to K8s, let's verify we understand how to persist Redis data.

```bash
cd ~/cloudmart

# 1. Create a Docker volume for Redis
docker volume create redis-test-data

# 2. Run Redis with the volume
docker run -d --name redis-test \
  -v redis-test-data:/data \
  redis:alpine redis-server --appendonly yes

# 3. Write some data to Redis
docker exec redis-test redis-cli set mykey "Persistent Data"
docker exec redis-test redis-cli get mykey

# 4. Destroy the container (simulate crash)
docker rm -f redis-test

# 5. Start a NEW container with the SAME volume
docker run -d --name redis-test-2 \
  -v redis-test-data:/data \
  redis:alpine redis-server --appendonly yes

# 6. Verify data persisted!
docker exec redis-test-2 redis-cli get mykey
# Output should be: "Persistent Data"

# 7. Cleanup Docker resources
docker rm -f redis-test-2
docker volume rm redis-test-data
```

**Key Learning:** Docker volumes persist data beyond container lifecycle.

---

## Phase 2: Kubernetes Core - Namespace, Configs & Secrets

Now we move to Kubernetes. We will set up the foundation: namespace, ConfigMaps, and Secrets.

### Step 1: Create Namespace

```bash
# Create a dedicated namespace for our application
kubectl create namespace cloudmart

# Set it as the default for this session (optional but convenient)
kubectl config set-context --current --namespace=cloudmart

# Verify
kubectl config view --minify | grep namespace
```

### Step 2: Create Secrets for Sensitive Data

```bash
# Create a Secret for the Redis password
kubectl create secret generic redis-secret \
  --from-literal=password='SuperSecretPass123!' \
  -n cloudmart

# Verify the secret was created
kubectl get secrets -n cloudmart

# View secret details (base64 encoded)
kubectl get secret redis-secret -n cloudmart -o yaml
```

### Step 3: Create ConfigMap for Application Settings

```bash
cat > ~/cloudmart/app-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: cloudmart
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
EOF

kubectl apply -f ~/cloudmart/app-config.yaml

# Verify
kubectl get configmaps -n cloudmart
kubectl describe configmap app-config -n cloudmart
```

---

## Phase 3: Deploy the Database (Redis)

We will deploy Redis with password protection and persistence.

### Step 1: Create Redis Deployment

```bash
cat > ~/cloudmart/redis-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: cloudmart
  labels:
    app: redis
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: database
    spec:
      containers:
      - name: redis
        image: redis:alpine
        command: ["redis-server", "--requirepass", "$(REDIS_PASSWORD)", "--appendonly", "yes"]
        ports:
        - containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: redis-storage
        emptyDir: {}
EOF

kubectl apply -f ~/cloudmart/redis-deployment.yaml
```

> **Note on Persistence:** We use `emptyDir` for simplicity. In production, you would use a PersistentVolumeClaim (PVC). EmptyDir persists across container restarts but is deleted when the Pod is deleted.

### Step 2: Create Redis Service

```bash
cat > ~/cloudmart/redis-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: cloudmart
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF

kubectl apply -f ~/cloudmart/redis-service.yaml
```

### Step 3: Verify Redis Deployment

```bash
# Check pod status
kubectl get pods -n cloudmart -l app=redis

# Check service
kubectl get svc -n cloudmart

# Test Redis connectivity from inside the cluster
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -n cloudmart -- \
  redis-cli -h redis-service -a 'SuperSecretPass123!' ping

# Expected output: PONG
```

---

## Phase 4: Deploy the Backend API

Now we deploy our custom Inventory API that we built and loaded into KIND.

### Step 1: Create API Deployment

```bash
cat > ~/cloudmart/api-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-api
  namespace: cloudmart
  labels:
    app: inventory-api
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inventory-api
  template:
    metadata:
      labels:
        app: inventory-api
        tier: backend
    spec:
      containers:
      - name: api
        image: cloudmart-api:v1
        imagePullPolicy: Never  # Use locally loaded image
        ports:
        - containerPort: 5000
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 15
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF

kubectl apply -f ~/cloudmart/api-deployment.yaml
```

### Step 2: Create API Service (ClusterIP)

```bash
cat > ~/cloudmart/api-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  namespace: cloudmart
spec:
  selector:
    app: inventory-api
  ports:
  - port: 80
    targetPort: 5000
  type: ClusterIP
EOF

kubectl apply -f ~/cloudmart/api-service.yaml
```

### Step 3: Verify API Deployment

```bash
# Check pods
kubectl get pods -n cloudmart -l app=inventory-api

# Check if environment variables are injected correctly
kubectl exec -n cloudmart deploy/inventory-api -- env | grep -E 'REDIS|APP_ENV'

# Test the API from inside the cluster
kubectl run curl-test --rm -it --restart=Never --image=curlimages/curl -n cloudmart -- \
  curl -s http://inventory-service/
```

---

## Phase 5: Deploy the Frontend (Storefront)

The frontend needs to be accessible from outside the cluster.

### Step 1: Create Frontend Deployment

```bash
cat > ~/cloudmart/frontend-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  namespace: cloudmart
  labels:
    app: storefront
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: storefront
  template:
    metadata:
      labels:
        app: storefront
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 20
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
EOF

kubectl apply -f ~/cloudmart/frontend-deployment.yaml
```

### Step 2: Expose Frontend via NodePort

> **Note:** If port 30080 is already allocated, change `nodePort` to another value in the 30000-32767 range (e.g., 30081).

```bash
cat > ~/cloudmart/frontend-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: storefront-service
  namespace: cloudmart
spec:
  type: NodePort
  selector:
    app: storefront
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

kubectl apply -f ~/cloudmart/frontend-service.yaml
```

### Step 3: Access the Frontend

```bash
# Get the control-plane container's IP (KIND-specific)
CONTROL_PLANE_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-cluster-control-plane)
echo "Frontend URL: http://$CONTROL_PLANE_IP:30080"

# Test from the Ubuntu VM
curl -I http://$CONTROL_PLANE_IP:30080

# Alternative: Use kubectl port-forward for local access
# kubectl port-forward -n cloudmart svc/storefront-service 8080:80 &
# curl http://localhost:8080
```

---

## Phase 6: Advanced Workloads - DaemonSets & Jobs

### Step 1: Node Monitor DaemonSet

Create an agent that runs on **every node** (including control-plane).

```bash
cat > ~/cloudmart/node-monitor.yaml <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
  namespace: cloudmart
  labels:
    app: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      # Toleration to run on control-plane nodes
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: monitor
        image: busybox:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "[$(date)] Node: $(hostname) | Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
            sleep 30
          done
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "25m"
EOF

kubectl apply -f ~/cloudmart/node-monitor.yaml
```

**Verify DaemonSet runs on ALL nodes:**
```bash
# Should show DESIRED=2, CURRENT=2, READY=2
kubectl get daemonsets -n cloudmart

# Should show one pod per node
kubectl get pods -n cloudmart -l app=node-monitor -o wide

# Check logs from one of the monitors
kubectl logs -n cloudmart -l app=node-monitor --tail=5
```

### Step 2: Database Migration Job (One-off Task)

```bash
cat > ~/cloudmart/db-init-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: db-init
  namespace: cloudmart
spec:
  template:
    spec:
      containers:
      - name: migrator
        image: redis:alpine
        command:
        - /bin/sh
        - -c
        - |
          echo "=== Database Migration Started ==="
          echo "Connecting to Redis at redis-service..."
          redis-cli -h redis-service -a "$REDIS_PASSWORD" ping
          echo "Setting initial data..."
          redis-cli -h redis-service -a "$REDIS_PASSWORD" set app:version "1.0.0"
          redis-cli -h redis-service -a "$REDIS_PASSWORD" set app:initialized "$(date)"
          echo "=== Migration Complete ==="
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
      restartPolicy: OnFailure
  backoffLimit: 3
  ttlSecondsAfterFinished: 300
EOF

kubectl apply -f ~/cloudmart/db-init-job.yaml
```

**Verify the Job:**
```bash
# Watch job complete
kubectl get jobs -n cloudmart --watch

# Check job logs
kubectl logs -n cloudmart job/db-init

# Verify data was written to Redis
kubectl run redis-check --rm -it --restart=Never --image=redis:alpine -n cloudmart -- \
  redis-cli -h redis-service -a 'SuperSecretPass123!' get app:version
```

### Step 3: Sales Report CronJob (Scheduled Task)

```bash
cat > ~/cloudmart/report-cronjob.yaml <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sales-report
  namespace: cloudmart
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes for testing
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox:latest
            command:
            - /bin/sh
            - -c
            - |
              echo "=== Sales Report Generation ==="
              echo "Timestamp: $(date)"
              echo "Report ID: REPORT-$(date +%Y%m%d%H%M%S)"
              echo "Processing sales data..."
              sleep 5
              echo "Report generated successfully!"
              echo "==============================="
          restartPolicy: OnFailure
EOF

kubectl apply -f ~/cloudmart/report-cronjob.yaml
```

**Verify CronJob:**
```bash
# Check CronJob status
kubectl get cronjobs -n cloudmart

# Wait 2 minutes and check for created jobs
kubectl get jobs -n cloudmart

# View logs from a completed job
JOB_NAME=$(kubectl get jobs -n cloudmart -l job-name -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$JOB_NAME" ]; then
  kubectl logs -n cloudmart job/$JOB_NAME
fi
```

---

## Phase 7: Final Verification & Testing

### Complete System Check

```bash
echo "=== CloudMart System Status ==="

echo -e "\n--- All Resources ---"
kubectl get all -n cloudmart

echo -e "\n--- ConfigMaps & Secrets ---"
kubectl get configmaps,secrets -n cloudmart

echo -e "\n--- Pod Distribution ---"
kubectl get pods -n cloudmart -o wide

echo -e "\n--- Service Endpoints ---"
kubectl get endpoints -n cloudmart
```

### Test End-to-End Connectivity

```bash
# 1. Test API internally
kubectl run test-client --rm -it --restart=Never --image=curlimages/curl -n cloudmart -- \
  curl -s http://inventory-service/

# 2. Test frontend externally
CONTROL_PLANE_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-cluster-control-plane)
curl -s -o /dev/null -w "%{http_code}" http://$CONTROL_PLANE_IP:30080

# 3. Verify Redis data
kubectl run redis-final --rm -it --restart=Never --image=redis:alpine -n cloudmart -- \
  redis-cli -h redis-service -a 'SuperSecretPass123!' keys '*'
```

---

## Troubleshooting Guide

### Pod Not Starting

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n cloudmart

# Check logs
kubectl logs <pod-name> -n cloudmart

# Common issues:
# - ImagePullBackOff: Image not found. Run `kind load docker-image <image> --name kind-cluster`
# - CrashLoopBackOff: Application error. Check logs.
# - Pending: Resource constraints or node issues.
```

### Cannot Access NodePort Service

```bash
# For KIND clusters, use the container IP, not localhost
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-cluster-control-plane

# Or use port-forward
kubectl port-forward -n cloudmart svc/storefront-service 8080:80
```

### NodePort Already Allocated

If you see `Invalid value: 30080: provided port is already allocated`:

```bash
# Option 1: Find what's using the port and change your nodePort value
kubectl get svc --all-namespaces | grep 30080

# Option 2: Edit the service YAML to use a different port (e.g., 30081)
# Then update the corresponding curl commands to use the new port
```

### Secret/ConfigMap Not Injected

```bash
# Verify the secret exists
kubectl get secret redis-secret -n cloudmart -o yaml

# Check pod's environment
kubectl exec -n cloudmart deploy/inventory-api -- env
```

---

## Cleanup

To remove all resources created in this lab:

```bash
# 1. Delete the namespace (removes all K8s objects)
kubectl delete namespace cloudmart

# 2. Remove the locally built image (optional)
docker rmi cloudmart-api:v1

# 3. Clean up lab directory
rm -rf ~/cloudmart

# 4. Reset kubectl context to default namespace
kubectl config set-context --current --namespace=default

# Verify cleanup
kubectl get all -n cloudmart 2>/dev/null || echo "Namespace deleted successfully"
```

---

## Summary of Concepts Practiced

| Concept | Where Used |
|---------|------------|
| **Docker Build** | Phase 1 - Building cloudmart-api:v1 |
| **Docker Volumes** | Phase 1 - Redis persistence test |
| **KIND Image Loading** | Phase 1 - `kind load docker-image` |
| **Namespaces** | Phase 2 - cloudmart namespace |
| **Secrets** | Phase 2 - Redis password |
| **ConfigMaps** | Phase 2 - Application config |
| **Deployments** | Phases 3-5 - Redis, API, Frontend |
| **Services (ClusterIP)** | Phases 3-4 - Internal services |
| **Services (NodePort)** | Phase 5 - External access |
| **Probes** | Phase 4-5 - Health checks |
| **DaemonSets** | Phase 6 - Node monitor |
| **Jobs** | Phase 6 - DB migration |
| **CronJobs** | Phase 6 - Scheduled reports |

---

## Next Steps (Optional Challenges)

1. **Add a PersistentVolumeClaim** for Redis to survive pod deletions
2. **Implement Horizontal Pod Autoscaling** for the API
3. **Add Network Policies** to restrict traffic between tiers
4. **Deploy an Ingress Controller** instead of NodePort
5. **Implement Rolling Updates** with zero downtime
