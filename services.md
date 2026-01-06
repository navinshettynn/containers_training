# Kubernetes Services – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the kubectl Commands Lab and Pods Lab** (this lab builds on those skills)

> **Important**: This lab assumes familiarity with basic kubectl commands (`get`, `describe`, `apply`, `delete`, `logs`, `exec`) and Pod concepts (labels, selectors, readiness probes). If you haven't completed the previous labs, do those first.

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

- Understand what **Service Discovery** is and why it's needed in Kubernetes
- Learn how the **Service object** provides stable networking for Pods
- Create and configure different **Service types** (ClusterIP, NodePort)
- Use **DNS-based service discovery** within the cluster
- Understand **Endpoints** and how Services select Pods
- Configure **selector-less services** for external resources
- Use **ExternalName** services for DNS aliases
- Implement **Headless Services** for direct Pod discovery

### Intermediate Objectives (Optional)

- Understand **Session Affinity** for sticky sessions
- Configure **multi-port Services**
- Use **service environment variables** for legacy applications
- Integrate services with **Deployments** for real-world patterns

---

## What is Service Discovery?

In Kubernetes, Pods are ephemeral – they can be created, destroyed, and rescheduled at any time. This creates a challenge: **How do you find which Pods are running your application?**

### The Problem with Direct Pod Communication

| Challenge | Description |
|-----------|-------------|
| **Dynamic IPs** | Pods get new IP addresses when recreated |
| **Scaling** | Number of Pods changes based on load |
| **Placement** | Pods can move between nodes |
| **Health** | Unhealthy Pods should be excluded |

### Why Not Just Use DNS?

Traditional DNS has limitations:

- **Caching**: Clients may cache stale IP addresses
- **TTL delays**: Changes take time to propagate
- **Record limits**: DNS struggles with many A records (20-30+)
- **No load balancing**: Clients typically use the first IP returned

### The Solution: Kubernetes Services

A Service provides:

| Feature | Description |
|---------|-------------|
| **Stable IP** | Virtual IP (ClusterIP) that doesn't change |
| **Load balancing** | Distributes traffic across healthy Pods |
| **Service discovery** | DNS names within the cluster |
| **Health integration** | Only routes to ready Pods |

---

## Service Types Overview

| Type | Description | Use Case |
|------|-------------|----------|
| `ClusterIP` | Internal-only virtual IP | Default; internal communication |
| `NodePort` | Exposes on each node's IP | External access without load balancer |
| `LoadBalancer` | Cloud load balancer | Production external access |
| `ExternalName` | DNS CNAME alias | Reference external services |

> **KIND Note**: LoadBalancer type requires additional setup (MetalLB) in KIND clusters. We'll focus on ClusterIP and NodePort in this lab.

---

## Part 1: Creating Services with Deployments

Services work with Pods, but in practice, you'll use them with Deployments for scalability and resilience.

### Create a Lab Directory

```bash
mkdir -p ~/services-lab
cd ~/services-lab
```

### Create a Deployment for Our Application

```bash
cat > alpaca-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpaca-prod
  labels:
    app: alpaca
    env: prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: alpaca
  template:
    metadata:
      labels:
        app: alpaca
        env: prod
    spec:
      containers:
      - name: alpaca
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
EOF

kubectl apply -f alpaca-deployment.yaml
```

### Wait for Pods to be Ready

```bash
kubectl get pods -l app=alpaca --watch
```

Press `Ctrl+C` when all 3 pods show `1/1 Running`.

### Create a ClusterIP Service (Default Type)

```bash
cat > alpaca-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpaca-prod
spec:
  selector:
    app: alpaca
  ports:
  - port: 8080
    targetPort: 80
    protocol: TCP
EOF

kubectl apply -f alpaca-service.yaml
```

### View the Service

```bash
kubectl get services
kubectl get svc alpaca-prod
```

Output shows:

```
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
alpaca-prod   ClusterIP   10.96.xxx.xxx   <none>        8080/TCP   10s
```

### Service Specification Explained

| Field | Description |
|-------|-------------|
| `selector` | Label selector to find matching Pods |
| `port` | Port the service listens on |
| `targetPort` | Port on the Pod to forward traffic to |
| `protocol` | TCP (default) or UDP |

### View Service Details

```bash
kubectl describe service alpaca-prod
```

Note the `Endpoints` line – these are the Pod IPs that the service routes to.

### Test the Service from Within the Cluster

```bash
# Create a temporary pod to test the service
kubectl run test-client --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Test using the service name (DNS)
wget -qO- http://alpaca-prod:8080

# Test using the fully qualified name
wget -qO- http://alpaca-prod.default.svc.cluster.local:8080

# Exit
exit
```

The service load balances requests across all Pods!

---

## Part 2: Service DNS and Discovery

Kubernetes provides built-in DNS for service discovery.

### DNS Name Structure

The full DNS name for a service follows this pattern:

```
<service-name>.<namespace>.svc.cluster.local
```

| Component | Description |
|-----------|-------------|
| `<service-name>` | Name of the service |
| `<namespace>` | Namespace where service exists |
| `svc` | Indicates this is a service |
| `cluster.local` | Default cluster domain |

### Create a Second Deployment and Service

```bash
cat > bandicoot-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bandicoot-prod
  labels:
    app: bandicoot
    env: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bandicoot
  template:
    metadata:
      labels:
        app: bandicoot
        env: prod
    spec:
      containers:
      - name: bandicoot
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f bandicoot-deployment.yaml
kubectl expose deployment bandicoot-prod --port=8080 --target-port=80
```

### View Both Services

```bash
kubectl get services -o wide
```

### Test DNS Resolution

```bash
kubectl run dns-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Short name (same namespace)
nslookup alpaca-prod

# With namespace
nslookup alpaca-prod.default

# Fully qualified
nslookup alpaca-prod.default.svc.cluster.local

# Query another service
nslookup bandicoot-prod

exit
```

### Cross-Namespace Service Discovery

Create a service in another namespace:

```bash
kubectl create namespace backend
kubectl create deployment api-server --image=nginx:alpine -n backend
kubectl expose deployment api-server --port=80 -n backend
```

Access from default namespace:

```bash
kubectl run cross-ns-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Must use namespace in the DNS name
wget -qO- http://api-server.backend:80

# Or fully qualified
wget -qO- http://api-server.backend.svc.cluster.local:80

exit
```

### Cleanup Cross-Namespace Test

```bash
kubectl delete namespace backend
```

---

## Part 3: Understanding Endpoints

For every Service, Kubernetes creates an Endpoints object containing the IPs of selected Pods.

### View Endpoints

```bash
kubectl get endpoints
kubectl get endpoints alpaca-prod
```

### Watch Endpoints Change

Open two terminal windows.

**Terminal 1** – Watch endpoints:

```bash
kubectl get endpoints alpaca-prod --watch
```

**Terminal 2** – Scale the deployment:

```bash
# Scale up
kubectl scale deployment alpaca-prod --replicas=5
sleep 5

# Scale down
kubectl scale deployment alpaca-prod --replicas=2
sleep 5

# Restore
kubectl scale deployment alpaca-prod --replicas=3
```

Watch how the endpoints update in real-time as Pods are added and removed!

### View Detailed Endpoint Information

```bash
kubectl describe endpoints alpaca-prod
```

This shows:

- Ready addresses (Pods passing readiness checks)
- Not ready addresses (Pods failing readiness checks)
- Ports being exposed

### Demonstrate Readiness Integration

Create a deployment with a readiness probe that can fail:

```bash
cat > flaky-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flaky-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flaky
  template:
    metadata:
      labels:
        app: flaky
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          periodSeconds: 2
          failureThreshold: 2
EOF

kubectl apply -f flaky-deployment.yaml
kubectl expose deployment flaky-app --port=80
```

Watch the endpoints:

```bash
kubectl get endpoints flaky-app --watch
```

The endpoints will show `<none>` because `/ready` returns 404 (nginx doesn't have that path).

**Press `Ctrl+C` and cleanup:**

```bash
kubectl delete deployment flaky-app
kubectl delete service flaky-app
```

---

## Part 4: NodePort Services

NodePort exposes the service on every node's IP at a specific port.

### Convert Service to NodePort

```bash
cat > alpaca-nodeport.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpaca-nodeport
spec:
  type: NodePort
  selector:
    app: alpaca
  ports:
  - port: 8080
    targetPort: 80
    nodePort: 30080
EOF

kubectl apply -f alpaca-nodeport.yaml
```

### View NodePort Service

```bash
kubectl get svc alpaca-nodeport
kubectl describe svc alpaca-nodeport
```

Output shows:

```
NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
alpaca-nodeport   NodePort   10.96.xxx.xxx   <none>        8080:30080/TCP   10s
```

### NodePort Range

Kubernetes allocates NodePorts in the range **30000-32767** by default.

| Field | Description |
|-------|-------------|
| `port` | Service port (ClusterIP) |
| `targetPort` | Pod port |
| `nodePort` | Port on every node (30000-32767) |

### Access via NodePort in KIND

In KIND, nodes are Docker containers. Get the node's internal IP:

```bash
# Get the worker node IP
kubectl get nodes -o wide
```

Test from within the cluster:

```bash
kubectl run nodeport-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Get node IP (replace with actual IP from above)
wget -qO- http://<NODE_IP>:30080

exit
```

### Let System Assign NodePort

```bash
cat > auto-nodeport.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpaca-auto-nodeport
spec:
  type: NodePort
  selector:
    app: alpaca
  ports:
  - port: 8080
    targetPort: 80
    # nodePort omitted - system will assign one
EOF

kubectl apply -f auto-nodeport.yaml
kubectl get svc alpaca-auto-nodeport
```

The system automatically assigns an available port.

---

## Part 5: Selector-less Services (External Resources)

Sometimes you need to route to resources outside the cluster (databases, legacy systems).

### Create a Selector-less Service

```bash
cat > external-db-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  # No selector!
  ports:
  - port: 5432
    targetPort: 5432
EOF

kubectl apply -f external-db-service.yaml
```

### Create Manual Endpoints

```bash
cat > external-db-endpoints.yaml <<'EOF'
apiVersion: v1
kind: Endpoints
metadata:
  # Must match the service name
  name: external-database
subsets:
  - addresses:
      - ip: 192.168.1.100  # External database IP
      - ip: 192.168.1.101  # Backup database IP
    ports:
      - port: 5432
EOF

kubectl apply -f external-db-endpoints.yaml
```

### Verify the Configuration

```bash
kubectl get svc external-database
kubectl get endpoints external-database
kubectl describe svc external-database
```

Now applications can use `external-database:5432` to reach the external IPs!

### Use Case: Migrating to Kubernetes

1. Create selector-less service pointing to external database
2. Applications use the service DNS name
3. Later, deploy database in Kubernetes
4. Add selector to service, remove manual endpoints
5. No application changes needed!

---

## Part 6: ExternalName Services

ExternalName creates a DNS CNAME alias to an external DNS name.

### Create ExternalName Service

```bash
cat > external-api-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.example.com
EOF

kubectl apply -f external-api-service.yaml
```

### View the Service

```bash
kubectl get svc external-api
kubectl describe svc external-api
```

### How It Works

When a Pod looks up `external-api`, the cluster DNS returns a CNAME record pointing to `api.example.com`.

| Advantage | Description |
|-----------|-------------|
| **Abstraction** | Application uses internal name |
| **Easy updates** | Change external URL in one place |
| **No proxying** | Direct DNS resolution |

**Limitation**: Only works for DNS-resolvable names, not IP addresses.

---

## Part 7: Headless Services

Headless services don't provide load balancing – instead, they return the IPs of all Pods directly.

### Create a Headless Service

```bash
cat > alpaca-headless.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpaca-headless
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: alpaca
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl apply -f alpaca-headless.yaml
```

### Compare Regular vs Headless

```bash
# Regular service
kubectl get svc alpaca-prod

# Headless service
kubectl get svc alpaca-headless
```

The headless service shows `None` for CLUSTER-IP.

### Test DNS Resolution

```bash
kubectl run headless-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Regular service - returns single ClusterIP
nslookup alpaca-prod

# Headless service - returns all Pod IPs!
nslookup alpaca-headless

exit
```

### Use Cases for Headless Services

| Use Case | Description |
|----------|-------------|
| **StatefulSets** | Each Pod needs a stable DNS name |
| **Client-side load balancing** | Application handles load balancing |
| **Service mesh** | External proxy handles routing |
| **Peer discovery** | Pods need to discover each other |

---

## Part 8: Multi-Port Services

Services can expose multiple ports for applications that listen on several ports.

### Create a Multi-Port Service

```bash
cat > multi-port-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-port
  template:
    metadata:
      labels:
        app: multi-port
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
EOF

kubectl apply -f multi-port-deployment.yaml
```

```bash
cat > multi-port-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: multi-port-svc
spec:
  selector:
    app: multi-port
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
EOF

kubectl apply -f multi-port-service.yaml
```

### View Multi-Port Service

```bash
kubectl get svc multi-port-svc
kubectl describe svc multi-port-svc
```

**Note**: When a service exposes multiple ports, each port must have a `name`.

---

## Part 9: Session Affinity

Session affinity routes requests from the same client to the same Pod.

### Create Service with Session Affinity

```bash
cat > sticky-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpaca-sticky
spec:
  selector:
    app: alpaca
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
  ports:
  - port: 8080
    targetPort: 80
EOF

kubectl apply -f sticky-service.yaml
```

### View Session Affinity Configuration

```bash
kubectl describe svc alpaca-sticky
```

### Session Affinity Options

| Value | Description |
|-------|-------------|
| `None` | Default; requests distributed across Pods |
| `ClientIP` | Requests from same IP go to same Pod |

### Test Session Affinity

```bash
kubectl run sticky-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container:

```sh
# Multiple requests go to the same Pod
for i in 1 2 3 4 5; do
  wget -qO- http://alpaca-sticky:8080 | head -1
  sleep 1
done

exit
```

---

## Part 10: Service Environment Variables

Kubernetes injects service information as environment variables into Pods.

### View Service Environment Variables

```bash
kubectl run env-test --image=busybox:latest --rm -it --restart=Never -- env | grep -i alpaca
```

You'll see variables like:

```
ALPACA_PROD_SERVICE_HOST=10.96.xxx.xxx
ALPACA_PROD_SERVICE_PORT=8080
ALPACA_PROD_PORT=tcp://10.96.xxx.xxx:8080
```

### Environment Variable Naming

For a service named `my-service`:

| Variable | Value |
|----------|-------|
| `MY_SERVICE_SERVICE_HOST` | ClusterIP address |
| `MY_SERVICE_SERVICE_PORT` | Service port |
| `MY_SERVICE_PORT` | Full URL |

### Limitation

Services must exist **before** the Pods that need them – environment variables are set at Pod startup.

**Recommendation**: Use DNS instead of environment variables for service discovery.

---

## Exercises

> **Note**: These exercises focus on Service-specific features. Basic kubectl commands were covered in the **kubectl Commands Lab**, and Pod concepts in the **Pods Lab**.

### Exercise 1: Create a Complete Service Stack

Create a frontend and backend with proper service discovery:

```bash
cd ~/services-lab

# Create backend deployment and service
cat > backend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl apply -f backend.yaml

# Create frontend that connects to backend
cat > frontend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: web
        image: busybox:latest
        command: ["sh", "-c", "while true; do wget -qO- http://backend-svc:80 && sleep 5; done"]
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  labels:
    tier: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30001
EOF

kubectl apply -f frontend.yaml
```

Verify:

```bash
kubectl get deployments
kubectl get services
kubectl get pods --show-labels
kubectl logs -l app=frontend --tail=5
```

Cleanup:

```bash
kubectl delete -f frontend.yaml
kubectl delete -f backend.yaml
```

### Exercise 2: Endpoint Observation

Observe how endpoints change with Pod lifecycle:

```bash
# Terminal 1: Watch endpoints
kubectl get endpoints alpaca-prod --watch

# Terminal 2: Delete a pod
kubectl delete pod -l app=alpaca --wait=false

# Watch the endpoint disappear and reappear as the pod is replaced
```

### Exercise 3: Create a Database Service (Selector-less)

Simulate connecting to an external database:

```bash
cat > postgres-external.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
  - port: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: postgres
subsets:
  - addresses:
      - ip: 10.0.0.100
    ports:
      - port: 5432
EOF

kubectl apply -f postgres-external.yaml

# Verify
kubectl get svc postgres
kubectl get endpoints postgres
kubectl describe svc postgres
```

Test DNS resolution:

```bash
kubectl run postgres-test --image=busybox:latest --rm -it --restart=Never -- nslookup postgres
```

Cleanup:

```bash
kubectl delete -f postgres-external.yaml
```

---

## Optional Advanced Exercises

### Exercise 4: Service Discovery Across Namespaces

```bash
# Create namespaces
kubectl create namespace team-a
kubectl create namespace team-b

# Deploy service in team-a
kubectl create deployment webapp --image=nginx:alpine -n team-a
kubectl expose deployment webapp --port=80 -n team-a

# Access from team-b
kubectl run test --image=busybox:latest -n team-b --rm -it --restart=Never -- \
  wget -qO- http://webapp.team-a.svc.cluster.local:80

# Cleanup
kubectl delete namespace team-a team-b
```

### Exercise 5: Compare Load Balancing Behavior

```bash
# Create test pod
kubectl run lb-test --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside the container, make multiple requests and observe distribution:

```sh
# Regular service (should hit different pods)
for i in $(seq 1 10); do
  wget -qO- http://alpaca-prod:8080 2>/dev/null | head -1
done

# Sticky service (should hit same pod)
for i in $(seq 1 10); do
  wget -qO- http://alpaca-sticky:8080 2>/dev/null | head -1
done

exit
```

### Exercise 6: Headless Service for Pod Discovery

Use headless service to get all Pod IPs:

```bash
kubectl run discovery --image=busybox:latest --rm -it --restart=Never -- sh
```

Inside:

```sh
# Get all Pod IPs via DNS
nslookup alpaca-headless

# Connect to each Pod directly
for ip in $(nslookup alpaca-headless 2>/dev/null | grep Address | tail -n+2 | awk '{print $2}'); do
  echo "Connecting to $ip..."
  wget -qO- http://$ip:80 | head -1
done

exit
```

---

## Key Takeaways

- **Services** provide stable networking for dynamic Pods via virtual IPs and DNS
- **ClusterIP** is the default type for internal cluster communication
- **NodePort** exposes services on each node's IP for external access
- **DNS names** follow the pattern `<service>.<namespace>.svc.cluster.local`
- **Endpoints** are automatically managed based on label selectors and readiness
- **Selector-less services** enable routing to external resources
- **ExternalName** creates DNS aliases to external services
- **Headless services** return all Pod IPs for client-side load balancing
- **Session affinity** routes same client to same Pod
- Services integrate with **readiness probes** – only ready Pods receive traffic

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl get services` or `kubectl get svc` | List services |
| `kubectl get svc -o wide` | List with selector info |
| `kubectl describe svc <name>` | Detailed service info |
| `kubectl get endpoints` | List endpoints |
| `kubectl expose deployment <name>` | Create service for deployment |
| `kubectl expose deployment <name> --type=NodePort` | Create NodePort service |
| `kubectl expose deployment <name> --port=80 --target-port=8080` | Specify ports |

### Service Manifest Template

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  labels:
    app: myapp
spec:
  type: ClusterIP  # or NodePort, LoadBalancer, ExternalName
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  # For NodePort
  # - nodePort: 30080
  # For session affinity
  # sessionAffinity: ClientIP
```

### Service Types Summary

| Type | ClusterIP | NodePort | External Access |
|------|-----------|----------|-----------------|
| ClusterIP | Yes | No | No |
| NodePort | Yes | Yes | Via Node IP:NodePort |
| LoadBalancer | Yes | Yes | Via Load Balancer IP |
| ExternalName | No (CNAME) | No | DNS redirect |

### DNS Lookup Patterns

| Pattern | Scope |
|---------|-------|
| `<service>` | Same namespace |
| `<service>.<namespace>` | Cross-namespace |
| `<service>.<namespace>.svc` | Explicit service |
| `<service>.<namespace>.svc.cluster.local` | Fully qualified |

---

## Cleanup (End of Lab)

```bash
# Delete all services and deployments created in this lab
kubectl delete svc alpaca-prod alpaca-nodeport alpaca-auto-nodeport \
  external-database external-api alpaca-headless multi-port-svc \
  alpaca-sticky bandicoot-prod 2>/dev/null || true

kubectl delete deployment alpaca-prod bandicoot-prod multi-port-app 2>/dev/null || true

kubectl delete endpoints external-database 2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/services-lab

# Verify cleanup
kubectl get svc
kubectl get deployments
kubectl get endpoints
```

---

## Troubleshooting Common Issues

### Service Not Routing Traffic

```bash
# Check if service has endpoints
kubectl get endpoints <service-name>

# If empty, check:
# 1. Selector matches pod labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels

# 2. Pods are Running and Ready
kubectl get pods -l <selector>

# 3. Readiness probes are passing
kubectl describe pod <pod-name> | grep -A 5 "Readiness"
```

### DNS Resolution Fails

```bash
# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test from within a pod
kubectl run dns-debug --image=busybox:latest --rm -it --restart=Never -- nslookup kubernetes
```

### NodePort Not Accessible

```bash
# Verify NodePort is assigned
kubectl get svc <service-name> -o jsonpath='{.spec.ports[0].nodePort}'

# Check node IPs
kubectl get nodes -o wide

# Test from within cluster first
kubectl run test --image=busybox:latest --rm -it --restart=Never -- wget -qO- http://<node-ip>:<nodeport>
```

### Endpoints Show Wrong IPs

```bash
# Check selector matches
kubectl get svc <service-name> -o yaml | grep -A 5 selector
kubectl get pods --show-labels

# Manually check what pods should match
kubectl get pods -l <selector> -o wide
```

### Session Affinity Not Working

```bash
# Verify session affinity is configured
kubectl get svc <service-name> -o yaml | grep -A 5 sessionAffinity

# Note: Only works for requests from the same source IP
# Load balancers may interfere with client IP detection
```

---

## Additional Resources

- [Kubernetes Services Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Connecting Applications with Services](https://kubernetes.io/docs/tutorials/services/connect-applications-service/)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)


