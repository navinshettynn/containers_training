# Kubernetes Service Meshes – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services, Deployments)
4. Your VM has at least **8GB RAM** and **4 CPU cores** (Istio requires significant resources)

> **Important**: This lab assumes familiarity with kubectl commands, Pods, Services, Deployments, and basic networking concepts. If you haven't completed the previous labs, do those first.

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

### Core Service Mesh Concepts

- Understand what a **Service Mesh** is and why it's needed
- Learn the **data plane** vs **control plane** architecture
- Understand **sidecar proxy** injection patterns
- Learn how service meshes provide **observability**, **security**, and **traffic management**

### Practical Skills (Istio)

- Install and configure **Istio** on a KIND cluster
- Enable **automatic sidecar injection**
- Configure **traffic routing** and **traffic shifting**
- Implement **mutual TLS (mTLS)** for secure service-to-service communication
- Set up **canary deployments** with weighted routing
- Configure **circuit breaking** and **retries**
- Access **observability tools** (Kiali, Jaeger, Grafana)

### Intermediate Objectives (Optional)

- Configure **rate limiting** and **fault injection**
- Implement **request timeouts** and **retries**
- Use **VirtualServices** and **DestinationRules** for advanced traffic management
- Configure **authorization policies** for fine-grained access control

---

## What is a Service Mesh?

A Service Mesh is a dedicated **infrastructure layer** for handling service-to-service communication in microservices architectures.

| Feature | Description |
|---------|-------------|
| **Traffic Management** | Load balancing, routing, retries, timeouts |
| **Security** | mTLS encryption, authentication, authorization |
| **Observability** | Metrics, distributed tracing, access logs |
| **Resilience** | Circuit breaking, fault injection, rate limiting |

### Why Do You Need a Service Mesh?

| Challenge | Without Service Mesh | With Service Mesh |
|-----------|---------------------|-------------------|
| **Service Discovery** | Manual configuration | Automatic discovery |
| **Load Balancing** | Basic round-robin | Advanced algorithms |
| **Security** | App-level implementation | Transparent mTLS |
| **Observability** | Custom instrumentation | Built-in metrics/traces |
| **Failure Handling** | Manual retry logic | Automatic retries/circuit breaking |
| **Canary Releases** | Complex deployment scripts | Declarative traffic splitting |

### Service Mesh Architecture

| Component | Description |
|-----------|-------------|
| **Data Plane** | Sidecar proxies (Envoy) handling all traffic |
| **Control Plane** | Management components configuring the proxies |
| **Sidecar Proxy** | Container injected alongside each Pod |

### Popular Service Mesh Implementations

| Service Mesh | Description | Complexity |
|--------------|-------------|------------|
| **Istio** | Full-featured, most popular | High |
| **Linkerd** | Lightweight, easy to use | Low |
| **Consul Connect** | HashiCorp ecosystem | Medium |
| **AWS App Mesh** | AWS native | Medium |

> **Lab Note**: This lab uses **Istio** as it's the most widely adopted service mesh and provides comprehensive features.

---

## Part 1: Installing Istio

### Create a Lab Directory

```bash
mkdir -p ~/service-mesh-lab
cd ~/service-mesh-lab
```

### Download Istio

```bash
# Download the latest Istio release
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -

# Move to the Istio package directory
cd istio-1.20.0

# Add istioctl to your PATH
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version --remote=false
```

### Install Istio on the Cluster

```bash
# Install Istio with the demo profile (includes all features for learning)
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
```

Expected output (all pods should be Running):

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-xxx                 1/1     Running   0          1m
istio-ingressgateway-xxx                1/1     Running   0          1m
istiod-xxx                              1/1     Running   0          1m
```

### View Istio Components

```bash
# View all Istio resources
kubectl get all -n istio-system

# View Istio Custom Resource Definitions (CRDs)
kubectl get crds | grep istio
```

### Istio Profiles Explained

| Profile | Components | Use Case |
|---------|------------|----------|
| `demo` | All features, lower resources | Learning/testing |
| `default` | Production-ready defaults | Production |
| `minimal` | Just istiod | Custom installations |
| `empty` | Nothing | Starting point |

### Enable Automatic Sidecar Injection

```bash
# Label the default namespace for automatic injection
kubectl label namespace default istio-injection=enabled

# Verify the label
kubectl get namespace default --show-labels
```

---

## Part 2: Deploying a Sample Application

We'll deploy the classic **Bookinfo** application to demonstrate service mesh features.

### Understanding Bookinfo Architecture

| Service | Description | Versions |
|---------|-------------|----------|
| **productpage** | Frontend UI (Python) | v1 |
| **details** | Book details (Ruby) | v1 |
| **reviews** | Book reviews (Java) | v1, v2, v3 |
| **ratings** | Star ratings (Node.js) | v1 |

The **reviews** service has three versions:
- **v1**: No ratings (no stars)
- **v2**: Black star ratings
- **v3**: Red star ratings

### Deploy Bookinfo Application

```bash
cd ~/service-mesh-lab/istio-1.20.0

# Deploy the application
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# Wait for all pods to be ready
kubectl get pods --watch
```

Wait until all pods show `2/2` Ready (application container + Envoy sidecar).

### Verify Sidecar Injection

```bash
# Check that pods have 2 containers (app + sidecar)
kubectl get pods

# Inspect a pod to see the sidecar
kubectl describe pod -l app=productpage | grep -A 5 "Containers:"
```

Expected output shows two containers:
- `productpage` (application)
- `istio-proxy` (Envoy sidecar)

### Verify Services

```bash
kubectl get services
```

### Test the Application Internally

```bash
# Exec into a pod and test
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -s productpage:9080/productpage | head -20
```

---

## Part 3: Exposing the Application with Istio Gateway

### Create Istio Gateway and VirtualService

```bash
# Apply the gateway configuration
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

# Verify the gateway was created
kubectl get gateway
kubectl get virtualservice
```

### Understanding Gateway vs VirtualService

| Resource | Purpose |
|----------|---------|
| **Gateway** | Configures the ingress load balancer (entry point) |
| **VirtualService** | Defines routing rules for traffic |

### Get the Ingress Gateway URL

```bash
# For KIND clusters, we need the NodePort
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "Gateway URL: http://$INGRESS_HOST:$INGRESS_PORT"
```

### Test the Gateway

```bash
# Test the productpage through the gateway
curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | head -50

# Verify you can reach the application
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

Expected output: `200`

### View Gateway Configuration

```bash
kubectl describe gateway bookinfo-gateway
kubectl describe virtualservice bookinfo
```

---

## Part 4: Traffic Management with Destination Rules

### Apply Destination Rules

Destination rules define policies that apply to traffic after routing.

```bash
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml

# Verify
kubectl get destinationrules
kubectl describe destinationrule reviews
```

### Understanding Destination Rules

```bash
cat > ~/service-mesh-lab/destination-rule-example.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF
```

| Field | Description |
|-------|-------------|
| `host` | Service name this rule applies to |
| `trafficPolicy` | Connection pool, load balancing settings |
| `subsets` | Named groups of service versions |

---

## Part 5: Routing All Traffic to v1

### Route All Traffic to Reviews v1

```bash
cat > ~/service-mesh-lab/reviews-v1-routing.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/reviews-v1-routing.yaml
```

### Test the Routing

```bash
# Make multiple requests - should always get no ratings (v1)
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o 'reviews-v[0-9]' || echo "v1 (no stars)"
  sleep 1
done
```

All requests should go to v1 (no star ratings displayed).

### View Active VirtualServices

```bash
kubectl get virtualservices
kubectl describe virtualservice reviews
```

---

## Part 6: Canary Deployment with Traffic Shifting

### Route 80% to v1, 20% to v2 (Canary)

```bash
cat > ~/service-mesh-lab/reviews-canary.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 80
    - destination:
        host: reviews
        subset: v2
      weight: 20
EOF

kubectl apply -f ~/service-mesh-lab/reviews-canary.yaml
```

### Test Traffic Distribution

```bash
# Make 10 requests and count versions
echo "Making 10 requests..."
for i in {1..10}; do
  response=$(curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage")
  
  if echo "$response" | grep -q 'font color="red"'; then
    echo "Request $i: v3 (red stars)"
  elif echo "$response" | grep -q 'font color="black"'; then
    echo "Request $i: v2 (black stars)"
  elif echo "$response" | grep -q 'glyphicon-star'; then
    echo "Request $i: v2/v3 (stars found)"
  else
    echo "Request $i: v1 (no stars)"
  fi
  sleep 1
done
```

You should see approximately 80% v1 and 20% v2.

### Gradually Shift Traffic (Blue-Green)

```bash
# 50/50 split
cat > ~/service-mesh-lab/reviews-50-50.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
EOF

kubectl apply -f ~/service-mesh-lab/reviews-50-50.yaml
```

### Complete Migration to v3

```bash
cat > ~/service-mesh-lab/reviews-v3-full.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v3
      weight: 100
EOF

kubectl apply -f ~/service-mesh-lab/reviews-v3-full.yaml

# Verify all traffic goes to v3
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q 'font color="red"' && echo "Request $i: v3 (red stars)" || echo "Request $i: other"
  sleep 1
done
```

---

## Part 7: Header-Based Routing (A/B Testing)

### Route Based on User Header

```bash
cat > ~/service-mesh-lab/reviews-header-routing.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  # Route to v2 for user "testuser"
  - match:
    - headers:
        end-user:
          exact: testuser
    route:
    - destination:
        host: reviews
        subset: v2
  # Route to v3 for user "admin"
  - match:
    - headers:
        end-user:
          exact: admin
    route:
    - destination:
        host: reviews
        subset: v3
  # Default to v1 for everyone else
  - route:
    - destination:
        host: reviews
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/reviews-header-routing.yaml
```

### Test Header-Based Routing

```bash
echo "Testing different users..."

# Regular user (no header) - should get v1
echo "No user header:"
curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q "glyphicon-star" && echo "Has stars" || echo "v1 (no stars)"

# Note: The Bookinfo app passes the 'end-user' header when you log in.
# For CLI testing, we'll verify the VirtualService is configured correctly
kubectl get virtualservice reviews -o yaml | grep -A 20 "match:"
```

---

## Part 8: Mutual TLS (mTLS) Security

### Check Current mTLS Status

```bash
# View PeerAuthentication policies
kubectl get peerauthentication --all-namespaces

# Check if mTLS is enabled (Istio enables PERMISSIVE mode by default)
istioctl analyze
```

### Enable Strict mTLS

```bash
cat > ~/service-mesh-lab/mtls-strict.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -f ~/service-mesh-lab/mtls-strict.yaml
```

### Verify mTLS is Working

```bash
# Check that certificates are loaded in the proxy
istioctl proxy-config secret "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | head -10

# Check mTLS status using proxy-status
istioctl proxy-status

# Verify mesh-wide PeerAuthentication policy
kubectl get peerauthentication --all-namespaces

# Check that traffic still flows (mTLS is transparent to applications)
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -s http://reviews:9080/reviews/0 | head -3

# View TLS mode in Envoy endpoint config (look for "tlsMode": "istio")
istioctl proxy-config endpoint "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | grep reviews
```

### View mTLS Policy

```bash
kubectl get peerauthentication default -o yaml
```

### mTLS Modes Explained

| Mode | Description |
|------|-------------|
| `PERMISSIVE` | Accept both mTLS and plaintext (default) |
| `STRICT` | Only accept mTLS connections |
| `DISABLE` | Do not use mTLS |

---

## Part 9: Circuit Breaking

### Configure Circuit Breaker

```bash
cat > ~/service-mesh-lab/reviews-circuit-breaker.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews-cb
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        http2MaxRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
EOF

kubectl apply -f ~/service-mesh-lab/reviews-circuit-breaker.yaml
```

### Circuit Breaker Settings Explained

| Setting | Description |
|---------|-------------|
| `maxConnections` | Maximum number of TCP connections |
| `http1MaxPendingRequests` | Maximum pending HTTP requests |
| `consecutive5xxErrors` | Errors before ejection |
| `baseEjectionTime` | How long to eject unhealthy host |
| `maxEjectionPercent` | Max percentage of hosts to eject |

### Test Circuit Breaking

```bash
# Deploy a load testing tool
kubectl apply -f samples/httpbin/sample-client/fortio-deploy.yaml

# Wait for fortio to be ready
kubectl wait --for=condition=Ready pod -l app=fortio --timeout=60s

# Send traffic with 2 concurrent connections (should work)
FORTIO_POD=$(kubectl get pods -l app=fortio -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning \
  "http://reviews:9080/reviews/0"
```

### Check Circuit Breaker Status

```bash
kubectl exec "$FORTIO_POD" -c istio-proxy -- \
  pilot-agent request GET stats | grep reviews | grep pending
```

### Cleanup Circuit Breaker

```bash
kubectl delete destinationrule reviews-cb
```

---

## Part 10: Fault Injection

### Inject Delay Fault

```bash
cat > ~/service-mesh-lab/ratings-delay.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-delay.yaml
```

### Test Delay Injection

```bash
# This should take ~5 seconds due to injected delay
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by"
```

### Inject HTTP Abort Fault

```bash
cat > ~/service-mesh-lab/ratings-abort.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      abort:
        percentage:
          value: 50
        httpStatus: 500
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-abort.yaml
```

### Test Abort Injection

```bash
# Some requests should fail with errors
for i in {1..10}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q "Ratings service is currently unavailable" && \
    echo "Request $i: Failed (ratings unavailable)" || echo "Request $i: Success"
  sleep 1
done
```

### Cleanup Fault Injection

```bash
kubectl delete virtualservice ratings
```

---

## Part 11: Request Timeouts and Retries

### Configure Request Timeout

```bash
cat > ~/service-mesh-lab/reviews-timeout.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - timeout: 1s
    route:
    - destination:
        host: reviews
        subset: v2
EOF

kubectl apply -f ~/service-mesh-lab/reviews-timeout.yaml
```

### Configure Retries

```bash
cat > ~/service-mesh-lab/ratings-retry.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-retry.yaml
```

### Retry Configuration Options

| Setting | Description |
|---------|-------------|
| `attempts` | Number of retry attempts |
| `perTryTimeout` | Timeout per retry attempt |
| `retryOn` | Conditions that trigger retry |

### Cleanup Timeouts and Retries

```bash
kubectl delete virtualservice reviews ratings
```

---

## Part 12: Observability - Installing Addons

### Install Observability Addons

```bash
cd ~/service-mesh-lab/istio-1.20.0

# Install Kiali, Prometheus, Grafana, and Jaeger
kubectl apply -f samples/addons

# Wait for addons to be ready
kubectl rollout status deployment/kiali -n istio-system
kubectl rollout status deployment/prometheus -n istio-system
kubectl rollout status deployment/grafana -n istio-system
kubectl rollout status deployment/jaeger -n istio-system
```

### Verify Addon Installation

```bash
kubectl get pods -n istio-system | grep -E "kiali|prometheus|grafana|jaeger"
```

---

## Part 13: Accessing Observability Dashboards

### Access Kiali Dashboard (Service Mesh Visualization)

```bash
# In a new terminal, start port forwarding
kubectl port-forward svc/kiali -n istio-system 20001:20001 &

# Access at http://localhost:20001
echo "Kiali Dashboard: http://localhost:20001"
```

### Access Grafana Dashboard (Metrics)

```bash
kubectl port-forward svc/grafana -n istio-system 3000:3000 &

echo "Grafana Dashboard: http://localhost:3000"
```

### Access Jaeger Dashboard (Distributed Tracing)

```bash
kubectl port-forward svc/tracing -n istio-system 16686:80 &

echo "Jaeger Dashboard: http://localhost:16686"
```

### Generate Traffic for Visualization

```bash
# Generate traffic for observability tools
echo "Generating traffic for 60 seconds..."
for i in {1..60}; do
  curl -s -o /dev/null "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
  sleep 1
done
echo "Traffic generation complete!"
```

### View Istio Metrics

```bash
# View metrics in Prometheus
kubectl port-forward svc/prometheus -n istio-system 9090:9090 &

# Query example: istio_requests_total
echo "Prometheus: http://localhost:9090"
```

### Stop Port Forwarding

```bash
# Stop all port forwards when done
pkill -f "port-forward"
```

---

## Part 14: Authorization Policies

### Deny All Traffic by Default

```bash
cat > ~/service-mesh-lab/deny-all.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}  # Empty spec denies all traffic
EOF

kubectl apply -f ~/service-mesh-lab/deny-all.yaml

# Test - should fail
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

Expected output: `403` (Forbidden)

### Allow Specific Traffic

```bash
cat > ~/service-mesh-lab/allow-productpage.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-productpage
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
  - from:
    - source:
        namespaces: ["default"]
EOF

kubectl apply -f ~/service-mesh-lab/allow-productpage.yaml
```

### Allow Internal Service Communication

```bash
cat > ~/service-mesh-lab/allow-internal.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-details
  namespace: default
spec:
  selector:
    matchLabels:
      app: details
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ratings
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
EOF

kubectl apply -f ~/service-mesh-lab/allow-internal.yaml
```

### Test Authorization Policies

```bash
# Should now work with policies in place
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

### Cleanup Authorization Policies

```bash
kubectl delete authorizationpolicy deny-all allow-productpage allow-details allow-reviews allow-ratings
```

---

## Scenario-Based Exercises: Deploying "TechShop" Microservices Platform

You've been hired as a Platform Engineer at **TechShop**, an e-commerce company migrating to microservices. Your mission: implement a service mesh to improve security, observability, and traffic management.

> **Story Context**: TechShop had a major outage last month because one failing service caused cascading failures. The CTO has mandated implementing a service mesh to prevent this from happening again.

```bash
# Setup: Create your workspace
cd ~/service-mesh-lab
```

---

### Exercise 1: The Cascading Failure Problem

**Scenario**: Before implementing the service mesh, let's understand the problem. When the ratings service becomes slow, the entire application hangs.

**Your Task**: Demonstrate the cascading failure problem and then solve it with Istio.

#### Step 1: Create the Problem (Inject Delay)

```bash
# First, reset to baseline routing
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/bookinfo/networking/virtual-service-all-v1.yaml

# Inject a 10-second delay in ratings
cat > exercise-delay.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 10s
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f exercise-delay.yaml
```

#### Step 2: Observe the Problem

```bash
echo "Without timeout protection, requests hang for 10+ seconds..."
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by"
```

#### Step 3: Implement the Solution (Timeout)

```bash
cat > exercise-timeout-fix.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - timeout: 3s
    route:
    - destination:
        host: reviews
        subset: v1
EOF

kubectl apply -f exercise-timeout-fix.yaml
```

#### Step 4: Verify the Fix

```bash
echo "With timeout, requests fail fast instead of hanging..."
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by\|Sorry"
```

**📝 Key Learning**: Service meshes provide timeout protection that prevents cascading failures!

#### Step 5: Cleanup Exercise 1

```bash
kubectl delete virtualservice ratings reviews
rm exercise-delay.yaml exercise-timeout-fix.yaml
```

---

### Exercise 2: Safe Canary Deployment

**Scenario**: The development team has a new version of the reviews service (v3 with red stars). You need to safely roll it out to 10% of users first, then gradually increase.

**Your Task**: Implement a canary deployment with traffic shifting.

#### Step 1: Verify Current Routing

```bash
# Apply destination rules if not present
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/bookinfo/networking/destination-rule-all.yaml

# Route all to v1
cat > exercise-canary-v1.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF

kubectl apply -f exercise-canary-v1.yaml
echo "Currently: 100% v1"
```

#### Step 2: Start Canary (10% to v3)

```bash
cat > exercise-canary-10.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v3
      weight: 10
EOF

kubectl apply -f exercise-canary-10.yaml
echo "Canary started: 90% v1, 10% v3"
```

#### Step 3: Test the Canary Distribution

```bash
echo "Testing 20 requests (expect ~2 with red stars)..."
v1_count=0
v3_count=0
for i in {1..20}; do
  response=$(curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage")
  if echo "$response" | grep -q 'font color="red"'; then
    ((v3_count++))
    echo "Request $i: v3 (red stars)"
  else
    ((v1_count++))
  fi
done
echo ""
echo "Results: v1=$v1_count, v3=$v3_count"
```

#### Step 4: Increase to 50%

```bash
cat > exercise-canary-50.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
EOF

kubectl apply -f exercise-canary-50.yaml
echo "Increased: 50% v1, 50% v3"
```

#### Step 5: Complete Migration

```bash
cat > exercise-canary-full.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v3
      weight: 100
EOF

kubectl apply -f exercise-canary-full.yaml
echo "Migration complete: 100% v3"

# Verify
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q 'font color="red"' && \
    echo "Request $i: v3 ✓" || echo "Request $i: unexpected"
done
```

**📝 Key Learning**: Service meshes enable zero-downtime canary deployments with precise traffic control!

#### Step 6: Cleanup Exercise 2

```bash
kubectl delete virtualservice reviews
rm exercise-canary-*.yaml
```

---

### Exercise 3: Implementing Zero-Trust Security

**Scenario**: The security team requires all service-to-service communication to be encrypted and authenticated. Implement strict mTLS.

**Your Task**: Enable strict mTLS and verify secure communication.

#### Step 1: Check Current Security Mode

```bash
echo "Current mTLS status:"
kubectl get peerauthentication --all-namespaces
```

#### Step 2: Enable Strict mTLS

```bash
cat > exercise-mtls-strict.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -f exercise-mtls-strict.yaml
echo "Strict mTLS enabled!"
```

#### Step 3: Verify mTLS is Working

```bash
# Check that the application still works (all traffic now encrypted)
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"

# View TLS certificates
echo ""
echo "Service certificates:"
istioctl proxy-config secret "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" \
  -o json | grep -E "serialNumber|validityDuration" | head -6
```

#### Step 4: Test that Non-mTLS Traffic is Blocked

```bash
# Deploy a pod without sidecar
kubectl run test-no-mesh --image=busybox --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/test-no-mesh --timeout=30s

# Try to access services from outside the mesh (should fail with STRICT mTLS)
kubectl exec test-no-mesh -- wget -qO- http://reviews:9080/reviews/0 2>&1 | head -5 || echo "Connection blocked (expected with STRICT mTLS)"

# Cleanup test pod
kubectl delete pod test-no-mesh --wait=false
```

**📝 Key Learning**: Service meshes provide transparent mTLS encryption without application changes!

#### Step 5: Cleanup Exercise 3

```bash
kubectl delete peerauthentication default
rm exercise-mtls-strict.yaml
```

---

### Exercise 4: Implementing Resilience Patterns

**Scenario**: During peak traffic, the ratings service sometimes becomes overloaded. Implement circuit breaking to prevent cascading failures.

**Your Task**: Configure circuit breaking and test it under load.

#### Step 1: Configure Circuit Breaker

```bash
cat > exercise-circuit-breaker.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ratings-circuit-breaker
spec:
  host: ratings
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 2
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
EOF

kubectl apply -f exercise-circuit-breaker.yaml
echo "Circuit breaker configured!"
```

#### Step 2: Deploy Load Testing Tool

```bash
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/httpbin/sample-client/fortio-deploy.yaml
kubectl wait --for=condition=Ready pod -l app=fortio --timeout=60s
```

#### Step 3: Test Normal Load

```bash
echo "Testing with 2 concurrent connections (within limits)..."
FORTIO_POD=$(kubectl get pods -l app=fortio -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 2 -qps 0 -n 10 -loglevel Warning \
  "http://ratings:9080/ratings/0" 2>&1 | grep "Code"
```

#### Step 4: Test Overload (Trip Circuit)

```bash
echo "Testing with 10 concurrent connections (exceeds limits)..."
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 10 -qps 0 -n 50 -loglevel Warning \
  "http://ratings:9080/ratings/0" 2>&1 | grep -E "Code|overflow"
```

You should see some requests returning 503 (overflow) - the circuit breaker in action!

**📝 Key Learning**: Circuit breakers prevent service overload by failing fast when limits are exceeded!

#### Step 5: Cleanup Exercise 4

```bash
kubectl delete destinationrule ratings-circuit-breaker
kubectl delete -f ~/service-mesh-lab/istio-1.20.0/samples/httpbin/sample-client/fortio-deploy.yaml
rm exercise-circuit-breaker.yaml
```

---

### Exercise 5: Observability Challenge

**Scenario**: The operations team needs visibility into service communication patterns, latencies, and error rates.

**Your Task**: Use Istio's observability tools to analyze the service mesh.

#### Step 1: Generate Traffic

```bash
echo "Generating traffic for analysis..."
for i in {1..30}; do
  curl -s -o /dev/null "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
  sleep 0.5
done
echo "Traffic generated!"
```

#### Step 2: View Proxy Statistics

```bash
# View Envoy stats for productpage
echo "=== Productpage Proxy Stats ==="
kubectl exec "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" \
  -c istio-proxy -- pilot-agent request GET stats | grep -E "upstream_rq_total|upstream_rq_2xx" | head -10
```

#### Step 3: View Service Mesh Configuration

```bash
# View all Istio configurations
echo ""
echo "=== Istio Configuration Summary ==="
echo "VirtualServices:"
kubectl get virtualservices
echo ""
echo "DestinationRules:"
kubectl get destinationrules
echo ""
echo "Gateways:"
kubectl get gateways
echo ""
echo "PeerAuthentication:"
kubectl get peerauthentication --all-namespaces
```

#### Step 4: Analyze with istioctl

```bash
# Analyze the mesh for issues
echo ""
echo "=== Mesh Analysis ==="
istioctl analyze

# View service dependencies
echo ""
echo "=== Proxy Config for productpage ==="
istioctl proxy-config clusters "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | head -15
```

**📝 Key Learning**: Service meshes provide rich observability without code changes!

---

### Final Exercise: Complete Cleanup and Review

#### Step 1: Review All Resources

```bash
echo "╔════════════════════════════════════════════════╗"
echo "║   Service Mesh Lab Resources Summary           ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Istio Components:"
kubectl get pods -n istio-system | head -10
echo ""
echo "Bookinfo Application:"
kubectl get pods -l app
echo ""
echo "Istio Custom Resources:"
kubectl get virtualservices,destinationrules,gateways
```

#### Step 2: Key Takeaways Summary

```bash
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║          🎓 LAB COMPLETE - KEY TAKEAWAYS 🎓            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Exercise 1: Timeout Protection"
echo "   → Prevents cascading failures from slow services"
echo ""
echo "✅ Exercise 2: Canary Deployments"
echo "   → Safe, gradual rollouts with traffic shifting"
echo ""
echo "✅ Exercise 3: Zero-Trust Security"
echo "   → Automatic mTLS encryption between services"
echo ""
echo "✅ Exercise 4: Circuit Breaking"
echo "   → Fail fast to prevent service overload"
echo ""
echo "✅ Exercise 5: Observability"
echo "   → Built-in metrics, tracing, and visualization"
echo ""
echo "🚀 You now understand service mesh fundamentals!"
echo "════════════════════════════════════════════════════════"
```

---

## Key Takeaways

### Service Mesh Fundamentals

- **Service Mesh** provides a dedicated infrastructure layer for service-to-service communication
- **Data Plane** (Envoy sidecars) handles all traffic between services
- **Control Plane** (istiod) manages and configures the data plane
- Sidecars are **automatically injected** when namespace is labeled

### Traffic Management

- **VirtualServices** define routing rules (weights, matches, timeouts)
- **DestinationRules** define policies (load balancing, circuit breaking)
- **Traffic Shifting** enables canary deployments and A/B testing
- **Fault Injection** allows testing resilience without breaking production

### Security

- **mTLS** provides automatic encryption and authentication
- **PeerAuthentication** controls mTLS mode (PERMISSIVE, STRICT)
- **AuthorizationPolicies** enable fine-grained access control
- Zero-trust is achievable without application changes

### Resilience

- **Timeouts** prevent hanging requests from cascading
- **Retries** automatically retry failed requests
- **Circuit Breaking** prevents overloading failing services
- **Outlier Detection** removes unhealthy instances

### Observability

- **Kiali** provides service mesh visualization
- **Jaeger** provides distributed tracing
- **Grafana/Prometheus** provide metrics dashboards
- All without code instrumentation

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `istioctl install --set profile=demo -y` | Install Istio with demo profile |
| `istioctl analyze` | Analyze mesh for issues |
| `istioctl proxy-config clusters <pod>` | View proxy cluster config |
| `istioctl proxy-config routes <pod>` | View proxy route config |
| `istioctl proxy-config secret <pod>` | View proxy certificates |
| `kubectl label namespace <ns> istio-injection=enabled` | Enable sidecar injection |
| `kubectl get virtualservices` | List VirtualServices |
| `kubectl get destinationrules` | List DestinationRules |
| `kubectl get gateways` | List Gateways |
| `kubectl get peerauthentication` | List PeerAuthentication policies |
| `kubectl get authorizationpolicies` | List AuthorizationPolicies |

### VirtualService Manifest Template

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
  - my-service
  http:
  - match:
    - headers:
        user:
          exact: admin
    route:
    - destination:
        host: my-service
        subset: v2
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 90
    - destination:
        host: my-service
        subset: v2
      weight: 10
    timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
```

### DestinationRule Manifest Template

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: my-service
spec:
  host: my-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        http2MaxRequests: 100
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### Gateway Manifest Template

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.example.com"
```

### PeerAuthentication Manifest Template

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: my-namespace
spec:
  mtls:
    mode: STRICT  # or PERMISSIVE
```

### AuthorizationPolicy Manifest Template

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: my-policy
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/my-service-account"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

---

## Cleanup (End of Lab)

```bash
# Delete Bookinfo application
cd ~/service-mesh-lab/istio-1.20.0
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml

# Delete Bookinfo gateway
kubectl delete -f samples/bookinfo/networking/bookinfo-gateway.yaml

# Delete destination rules
kubectl delete -f samples/bookinfo/networking/destination-rule-all.yaml

# Delete observability addons
kubectl delete -f samples/addons

# Delete any remaining VirtualServices, DestinationRules, etc.
kubectl delete virtualservices --all
kubectl delete destinationrules --all
kubectl delete gateways --all
kubectl delete peerauthentication --all
kubectl delete authorizationpolicies --all

# Uninstall Istio
istioctl uninstall --purge -y
kubectl delete namespace istio-system

# Remove istio-injection label
kubectl label namespace default istio-injection-

# Remove lab directory
cd ~
rm -rf ~/service-mesh-lab

# Verify cleanup
kubectl get pods
kubectl get ns | grep istio
```

---

## Troubleshooting Common Issues

### Sidecar Not Injected

```bash
# Check namespace label
kubectl get namespace default --show-labels | grep istio-injection

# If missing, add it
kubectl label namespace default istio-injection=enabled

# Restart pods to inject sidecars
kubectl rollout restart deployment --all
```

### Gateway Not Accessible

```bash
# Check ingress gateway pods
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Check gateway configuration
kubectl describe gateway bookinfo-gateway

# Check VirtualService routes to gateway
kubectl get virtualservice -o yaml | grep -A 5 gateways

# Verify ports
kubectl get svc istio-ingressgateway -n istio-system
```

### Traffic Not Routing as Expected

```bash
# Analyze the mesh
istioctl analyze

# Check VirtualService configuration
kubectl describe virtualservice <name>

# Check DestinationRule subsets match pod labels
kubectl get pods --show-labels

# Check proxy configuration
istioctl proxy-config routes <pod-name>
```

### mTLS Issues

```bash
# Check PeerAuthentication
kubectl get peerauthentication --all-namespaces

# Check destination rule TLS settings
kubectl get destinationrule -o yaml | grep -A 5 tls

# Verify certificates
istioctl proxy-config secret <pod-name>
```

### Pods Crashing After Istio Installation

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check istio-proxy container logs
kubectl logs <pod-name> -c istio-proxy

# Common causes:
# - Insufficient resources (increase limits)
# - Init container failures
# - Configuration errors

# Check istiod logs
kubectl logs -n istio-system -l app=istiod
```

### Observability Tools Not Working

```bash
# Check addon pods
kubectl get pods -n istio-system | grep -E "kiali|prometheus|grafana|jaeger"

# Check addon services
kubectl get svc -n istio-system | grep -E "kiali|prometheus|grafana|tracing"

# Restart if needed
kubectl rollout restart deployment kiali -n istio-system
```

---

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Istio Observability](https://istio.io/latest/docs/concepts/observability/)
- [Bookinfo Sample Application](https://istio.io/latest/docs/examples/bookinfo/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs/)

