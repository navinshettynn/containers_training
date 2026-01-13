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

First, we create a dedicated directory for all our service mesh lab files. This keeps our work organized and makes cleanup easier later.

```bash
mkdir -p ~/service-mesh-lab
cd ~/service-mesh-lab
```

### Download Istio

Istio is distributed as a package containing the `istioctl` CLI tool, sample configurations, and manifests. We download a specific version (1.20.0) to ensure consistency across all lab participants.

```bash
# Download the latest Istio release
# The script detects your OS and downloads the appropriate package
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -

# Move to the Istio package directory
# This directory contains bin/, samples/, manifests/, and more
cd istio-1.20.0

# Add istioctl to your PATH
# istioctl is the primary CLI for installing, configuring, and debugging Istio
export PATH=$PWD/bin:$PATH

# Verify installation
# --remote=false checks the local binary version (Istio isn't installed yet)
istioctl version --remote=false
```

> **Why this matters**: `istioctl` is essential for managing Istio. It can install components, analyze configurations, debug proxies, and validate your service mesh setup. Always use matching versions of istioctl and Istio.

### Install Istio on the Cluster

Now we install Istio's control plane components onto our Kubernetes cluster. The installation creates a new namespace `istio-system` and deploys several components.

```bash
# Install Istio with the demo profile (includes all features for learning)
# The demo profile enables: istiod (control plane), ingress gateway, egress gateway,
# and configures lower resource limits suitable for learning environments
istioctl install --set profile=demo -y

# Verify installation - all pods should reach Running state
# This typically takes 1-2 minutes as images are pulled and containers start
kubectl get pods -n istio-system
```

Expected output (all pods should be Running):

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-xxx                 1/1     Running   0          1m
istio-ingressgateway-xxx                1/1     Running   0          1m
istiod-xxx                              1/1     Running   0          1m
```

> **What got installed**:
> - **istiod**: The control plane - manages configuration, certificate distribution, and sidecar injection
> - **istio-ingressgateway**: Entry point for external traffic into the mesh
> - **istio-egressgateway**: Exit point for traffic leaving the mesh (for security/monitoring)

### View Istio Components

Let's examine what Istio installed. This helps understand the architecture and verify everything is working.

```bash
# View all Istio resources (pods, services, deployments, etc.)
# Notice the ingress gateway service - this is how external traffic enters
kubectl get all -n istio-system

# View Istio Custom Resource Definitions (CRDs)
# CRDs extend Kubernetes with Istio-specific resources like VirtualService, Gateway, etc.
# These are the building blocks for configuring your service mesh
kubectl get crds | grep istio
```

> **Why CRDs matter**: Istio uses Kubernetes CRDs to provide a declarative way to configure traffic routing, security policies, and more. You'll use these throughout the lab.

### Istio Profiles Explained

| Profile | Components | Use Case |
|---------|------------|----------|
| `demo` | All features, lower resources | Learning/testing |
| `default` | Production-ready defaults | Production |
| `minimal` | Just istiod | Custom installations |
| `empty` | Nothing | Starting point |

> **For this lab**: We use `demo` because it includes all features (ingress, egress, telemetry) with resource limits appropriate for a KIND cluster. In production, you'd use `default` or customize based on needs.

### Enable Automatic Sidecar Injection

The magic of a service mesh happens through **sidecar proxies** - Envoy containers that run alongside your application containers. Instead of manually adding sidecars to every Pod, Istio can automatically inject them.

```bash
# Label the default namespace for automatic injection
# When this label is present, any new Pod created in this namespace
# will automatically get an Envoy sidecar injected
kubectl label namespace default istio-injection=enabled

# Verify the label was applied
kubectl get namespace default --show-labels
```

> **How injection works**: When you create a Pod in a labeled namespace, Kubernetes sends the Pod spec to Istio's webhook. Istio modifies the spec to add the `istio-proxy` (Envoy) container and an init container that sets up networking rules. This happens transparently - your application code doesn't change.

---

## Part 2: Deploying a Sample Application

We'll deploy the classic **Bookinfo** application to demonstrate service mesh features. Bookinfo is Istio's official sample app - a simple book review website composed of multiple microservices written in different languages.

### Understanding Bookinfo Architecture

| Service | Description | Versions |
|---------|-------------|----------|
| **productpage** | Frontend UI (Python) | v1 |
| **details** | Book details (Ruby) | v1 |
| **reviews** | Book reviews (Java) | v1, v2, v3 |
| **ratings** | Star ratings (Node.js) | v1 |

The **reviews** service has three versions - this is intentional for demonstrating traffic management:
- **v1**: No ratings (doesn't call ratings service - no stars displayed)
- **v2**: Black star ratings (calls ratings service, displays black stars)
- **v3**: Red star ratings (calls ratings service, displays red stars)

> **Why multiple versions?** This simulates a real-world scenario where you have different versions of a service running simultaneously. The service mesh lets you control which users see which version.

### Deploy Bookinfo Application

Now we deploy the application. Because we labeled the namespace for injection, each Pod will automatically get an Envoy sidecar.

```bash
cd ~/service-mesh-lab/istio-1.20.0

# Deploy the application
# This creates Deployments, Services, and ServiceAccounts for all Bookinfo components
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# Watch pods come up - notice the READY column
# It should show 2/2 (application container + istio-proxy sidecar)
kubectl get pods --watch
```

Wait until all pods show `2/2` Ready. This indicates:
- **First container**: Your application (productpage, details, reviews, or ratings)
- **Second container**: The Envoy sidecar proxy (`istio-proxy`)

> **Why 2/2?** The sidecar injection added an Envoy proxy container to each Pod. All traffic to/from your application now flows through this proxy, enabling all service mesh features.

### Verify Sidecar Injection

Let's confirm the sidecars were properly injected. This is a crucial verification step.

```bash
# Check that pods have 2 containers (app + sidecar)
# The READY column should show 2/2 for all pods
kubectl get pods

# Inspect a pod to see both containers
# You should see 'productpage' and 'istio-proxy' containers listed
kubectl describe pod -l app=productpage | grep -A 5 "Containers:"
```

Expected output shows two containers:
- `productpage` (application)
- `istio-proxy` (Envoy sidecar)

> **Troubleshooting**: If you see `1/1` instead of `2/2`, sidecars weren't injected. Check that the namespace has the `istio-injection=enabled` label, then delete and recreate the pods.

### Verify Services

Each microservice has a corresponding Kubernetes Service for discovery. Let's verify they exist.

```bash
# List all services - you should see productpage, details, reviews, ratings
kubectl get services
```

> **How services work with Istio**: Applications still use standard Kubernetes Service DNS names (e.g., `reviews:9080`). Istio intercepts this traffic at the sidecar level to apply routing rules, mTLS, etc.

### Test the Application Internally

Before exposing the app externally, let's verify it works within the cluster. We'll exec into a pod and make a request.

```bash
# Exec into the ratings pod and curl the productpage service
# This tests internal service-to-service communication through the mesh
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -s productpage:9080/productpage | head -20
```

> **What's happening**: This request goes through the mesh: ratings pod → ratings sidecar → productpage sidecar → productpage app. Even this simple curl is now getting mTLS encryption, metrics collection, and tracing automatically!

---

## Part 3: Exposing the Application with Istio Gateway

Now we need to expose our application to external traffic. Unlike standard Kubernetes Ingress, Istio uses its own **Gateway** resource combined with **VirtualService** for more powerful traffic control.

### Create Istio Gateway and VirtualService

The Gateway configures the ingress gateway pod to accept traffic, while the VirtualService defines how that traffic routes to services.

```bash
# Apply the gateway configuration
# This creates both a Gateway (L4-L6 config) and VirtualService (L7 routing)
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

# Verify the gateway was created
kubectl get gateway
kubectl get virtualservice
```

### Understanding Gateway vs VirtualService

| Resource | Purpose |
|----------|---------|
| **Gateway** | Configures the ingress load balancer (entry point) - defines ports, protocols, hosts |
| **VirtualService** | Defines routing rules for traffic - where requests go based on path, headers, etc. |

> **Why two resources?** This separation allows flexibility:
> - Multiple VirtualServices can share one Gateway
> - You can update routing without changing the gateway configuration
> - Gateway handles "what traffic to accept", VirtualService handles "where to send it"

### Get the Ingress Gateway URL

In a cloud environment, you'd get an external LoadBalancer IP. In KIND, we use NodePort to access the ingress gateway.

```bash
# For KIND clusters, we need the NodePort
# Get the port that maps to the ingress gateway's HTTP port
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# Get the IP address of a cluster node
export INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Display the URL you'll use to access the application
echo "Gateway URL: http://$INGRESS_HOST:$INGRESS_PORT"
```

> **Important**: Keep these environment variables set for the rest of the lab! Many commands depend on `$INGRESS_HOST` and `$INGRESS_PORT`.

### Test the Gateway

Let's verify external access through the Istio ingress gateway.

```bash
# Test the productpage through the gateway
# This request flow: curl → ingress gateway → productpage sidecar → productpage app
curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | head -50

# Verify you can reach the application (check HTTP status code)
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

Expected output: `200`

> **Traffic flow**: External request → Istio Ingress Gateway → VirtualService routing rules → destination Pod's sidecar → application container

### View Gateway Configuration

Let's examine what the Gateway and VirtualService actually configure.

```bash
# View Gateway details - notice the port/protocol configuration
kubectl describe gateway bookinfo-gateway

# View VirtualService details - notice the routing rules
# The 'match' section defines what requests to route
# The 'route' section defines where to send them
kubectl describe virtualservice bookinfo
```

> **Key observation**: The VirtualService binds to the gateway (`bookinfo-gateway`) and defines that requests to `/productpage` and `/static/*` should route to the `productpage` service on port 9080.

---

## Part 4: Traffic Management with Destination Rules

Before we can do advanced traffic management (like canary deployments), we need to define **DestinationRules**. These tell Istio about the different versions of our services.

### Apply Destination Rules

DestinationRules define **subsets** - named groups of Pod instances based on labels. They also configure traffic policies like connection pools and load balancing.

```bash
# Apply destination rules for all Bookinfo services
# This defines v1, v2, v3 subsets for each service based on the 'version' label
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml

# Verify the rules were created
kubectl get destinationrules

# Examine the reviews destination rule in detail
kubectl describe destinationrule reviews
```

> **Why do we need this?** Without DestinationRules, Istio doesn't know that `reviews-v1`, `reviews-v2`, and `reviews-v3` are different versions of the same service. The subsets map the names (v1, v2, v3) to Pod labels (version: v1, etc.).

### Understanding Destination Rules

Here's an example showing the structure of a DestinationRule:

```bash
cat > ~/service-mesh-lab/destination-rule-example.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews                    # The Kubernetes Service this applies to
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100        # Limit concurrent connections
  subsets:
  - name: v1                       # Subset name (used in VirtualService routing)
    labels:
      version: v1                  # Pods with this label belong to this subset
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
| `trafficPolicy` | Connection pool, load balancing, TLS settings applied to all subsets |
| `subsets` | Named groups of service versions identified by Pod labels |

> **VirtualService + DestinationRule**: These work together. VirtualService says "send 80% to subset v1, 20% to subset v2". DestinationRule says "subset v1 means Pods with label version=v1". Both are required for traffic splitting.

---

## Part 5: Routing All Traffic to v1

Now we'll demonstrate the core power of service mesh traffic management: controlling exactly which version of a service receives traffic. We start by routing **all** traffic to v1.

### Route All Traffic to Reviews v1

This is a common starting point before doing canary deployments - establish a baseline where 100% of traffic goes to the stable version.

```bash
# Create a VirtualService that routes all traffic to reviews v1
cat > ~/service-mesh-lab/reviews-v1-routing.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews                    # Intercept traffic to the 'reviews' service
  http:
  - route:
    - destination:
        host: reviews          # Send to the reviews service
        subset: v1             # Specifically to the v1 subset (defined in DestinationRule)
EOF

kubectl apply -f ~/service-mesh-lab/reviews-v1-routing.yaml
```

> **What happens**: When any service (like productpage) calls `reviews:9080`, the sidecar intercepts the request and routes it ONLY to Pods matching the v1 subset (those with label `version: v1`). v2 and v3 Pods are running but receive no traffic.

### Test the Routing

Let's verify all traffic goes to v1 (which shows no star ratings).

```bash
# Make multiple requests - should always get no ratings (v1)
# v1 doesn't call the ratings service, so no stars appear
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o 'reviews-v[0-9]' || echo "v1 (no stars)"
  sleep 1
done
```

All requests should go to v1 (no star ratings displayed).

> **Before vs After**: Without the VirtualService, Kubernetes round-robins between all reviews Pods (v1, v2, v3). With the VirtualService, Istio ensures 100% goes to v1 regardless of how many v2/v3 Pods exist.

### View Active VirtualServices

Let's examine our routing configuration.

```bash
# List all VirtualServices in the default namespace
kubectl get virtualservices

# View detailed routing rules for reviews
# Notice the 'route' section showing destination subset: v1
kubectl describe virtualservice reviews
```

> **Key insight**: The VirtualService is the "routing table" for the mesh. By changing it, you control traffic flow without touching application code or Kubernetes Deployments.

---

## Part 6: Canary Deployment with Traffic Shifting

**Canary deployment** is a technique where you roll out changes to a small subset of users before deploying to the entire infrastructure. Service meshes make this trivial with **weighted routing**.

### Route 80% to v1, 20% to v2 (Canary)

We'll send 80% of traffic to the stable v1 and 20% to the new v2 (black stars). This lets us test v2 with real users while limiting blast radius if something goes wrong.

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
      weight: 80             # 80% of traffic goes to v1
    - destination:
        host: reviews
        subset: v2
      weight: 20             # 20% of traffic goes to v2 (canary)
EOF

kubectl apply -f ~/service-mesh-lab/reviews-canary.yaml
```

> **How weights work**: Istio's sidecar proxies use weighted random selection. Over many requests, you'll see the specified distribution. Individual requests are randomly assigned, so you might not see exactly 80/20 in small samples.

### Test Traffic Distribution

Let's make multiple requests and observe the traffic split. v1 shows no stars, v2 shows black stars.

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

You should see approximately 80% v1 (no stars) and 20% v2 (black stars).

> **Real-world usage**: In production, you'd monitor error rates and latency for the canary (v2). If metrics look good, gradually increase the weight. If problems appear, instantly rollback by setting v1 to 100%.

### Gradually Shift Traffic (Blue-Green)

Let's increase to 50/50 split, this time between v1 and v3 (red stars). This demonstrates a gradual migration.

```bash
# 50/50 split between v1 and v3
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
      weight: 50             # Half to stable version
    - destination:
        host: reviews
        subset: v3
      weight: 50             # Half to new version
EOF

kubectl apply -f ~/service-mesh-lab/reviews-50-50.yaml
```

> **Blue-Green vs Canary**: Canary starts small (1-10%) and gradually increases. Blue-Green typically does a 50/50 or 100% switch. Both are easily achieved with service mesh weight configuration.

### Complete Migration to v3

Once confident in v3, complete the migration by sending 100% of traffic to it.

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
      weight: 100            # All traffic to v3
EOF

kubectl apply -f ~/service-mesh-lab/reviews-v3-full.yaml

# Verify all traffic goes to v3 (should all show red stars)
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q 'font color="red"' && echo "Request $i: v3 (red stars)" || echo "Request $i: other"
  sleep 1
done
```

> **Zero-downtime deployment**: Notice we never stopped any pods or services. All traffic shifting happened through configuration changes in the mesh. Old versions remain running (for quick rollback) until you're ready to scale them down.

---

## Part 7: Header-Based Routing (A/B Testing)

Beyond weight-based splitting, Istio can route traffic based on **request attributes** like headers, URI paths, query parameters, etc. This enables true A/B testing where specific users see specific versions.

### Route Based on User Header

We'll configure routing where:
- Users with header `end-user: testuser` → v2 (black stars)
- Users with header `end-user: admin` → v3 (red stars)  
- Everyone else → v1 (no stars)

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
  # Rule 1: Route to v2 for user "testuser"
  # The 'match' section defines conditions that must be true
  - match:
    - headers:
        end-user:
          exact: testuser      # Header must exactly match "testuser"
    route:
    - destination:
        host: reviews
        subset: v2
  # Rule 2: Route to v3 for user "admin"  
  - match:
    - headers:
        end-user:
          exact: admin
    route:
    - destination:
        host: reviews
        subset: v3
  # Rule 3: Default route (no match conditions) - catches everything else
  - route:
    - destination:
        host: reviews
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/reviews-header-routing.yaml
```

> **Rule ordering matters!** Istio evaluates rules top-to-bottom and uses the first match. The default route (no `match` section) should always be last.

### Test Header-Based Routing

The Bookinfo productpage app forwards the `end-user` header when a user logs in through the UI. For CLI testing, we verify the configuration.

```bash
echo "Testing different users..."

# Regular user (no header) - should get v1
echo "No user header:"
curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q "glyphicon-star" && echo "Has stars" || echo "v1 (no stars)"

# Note: The Bookinfo app passes the 'end-user' header when you log in.
# For CLI testing, we'll verify the VirtualService is configured correctly
kubectl get virtualservice reviews -o yaml | grep -A 20 "match:"
```

> **A/B Testing use cases**:
> - Show new features to internal testers (match company email domain)
> - Beta features for premium users (match subscription header)
> - Geographic routing (match region header from CDN)
> - Mobile vs desktop experiences (match User-Agent header)

---

## Part 8: Mutual TLS (mTLS) Security

**Mutual TLS** provides encrypted, authenticated service-to-service communication. Unlike regular TLS where only the client verifies the server, mTLS requires both sides to present certificates. Istio automates this entirely - no code changes needed!

### Check Current mTLS Status

By default, Istio enables mTLS in **PERMISSIVE** mode, meaning it accepts both encrypted and plaintext traffic.

```bash
# View PeerAuthentication policies
# If empty, Istio is using default PERMISSIVE mode
kubectl get peerauthentication --all-namespaces

# Check if mTLS is enabled and analyze any issues
# Istio enables PERMISSIVE mode by default
istioctl analyze
```

> **PERMISSIVE mode** is the default because it allows gradual migration. Services with sidecars can communicate via mTLS, while services without sidecars can still communicate via plaintext.

### Enable Strict mTLS

For true zero-trust security, enable **STRICT** mode. This rejects any non-mTLS traffic.

```bash
cat > ~/service-mesh-lab/mtls-strict.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default            # Applies to all services in default namespace
spec:
  mtls:
    mode: STRICT                # Only accept mTLS connections
EOF

kubectl apply -f ~/service-mesh-lab/mtls-strict.yaml
```

> **What STRICT does**: All incoming traffic to pods in the default namespace MUST be mTLS encrypted. Any plaintext connections are rejected. This enforces that only mesh members can communicate.

### Verify mTLS is Working

Let's verify certificates are in place and traffic still flows (now encrypted).

```bash
# Check that certificates are loaded in the proxy
# You should see certificates for the service's identity
istioctl proxy-config secret "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | head -10

# Check mTLS status using proxy-status
# All proxies should show SYNCED status
istioctl proxy-status

# Verify mesh-wide PeerAuthentication policy
kubectl get peerauthentication --all-namespaces

# Check that traffic still flows (mTLS is transparent to applications)
# Applications still use HTTP - the sidecar handles encryption
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -s http://reviews:9080/reviews/0 | head -3

# View TLS mode in Envoy endpoint config (look for "tlsMode": "istio")
istioctl proxy-config endpoint "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | grep reviews
```

> **Transparent encryption**: Notice the curl command uses `http://` not `https://`. The application code doesn't know about TLS - the sidecars handle encryption automatically. This is the power of service mesh!

### View mTLS Policy

Examine the PeerAuthentication policy we created.

```bash
kubectl get peerauthentication default -o yaml
```

### mTLS Modes Explained

| Mode | Description |
|------|-------------|
| `PERMISSIVE` | Accept both mTLS and plaintext (default - for migration) |
| `STRICT` | Only accept mTLS connections (for zero-trust security) |
| `DISABLE` | Do not use mTLS (for debugging or legacy services) |

> **Certificate management**: Istio automatically provisions, distributes, and rotates certificates. Each workload gets a unique identity certificate (SPIFFE ID) like `spiffe://cluster.local/ns/default/sa/bookinfo-productpage`. No manual certificate management needed!

---

## Part 9: Circuit Breaking

**Circuit breaking** is a resilience pattern that prevents cascading failures. When a service is overloaded or failing, the circuit breaker "trips" and returns errors immediately instead of waiting and potentially making things worse.

### Configure Circuit Breaker

We'll configure aggressive limits to demonstrate circuit breaking. In production, you'd set these based on actual capacity.

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
        maxConnections: 1           # Only allow 1 TCP connection
      http:
        http1MaxPendingRequests: 1  # Only 1 request can wait in queue
        http2MaxRequests: 1         # Only 1 concurrent HTTP/2 request
        maxRequestsPerConnection: 1 # Close connection after each request
    outlierDetection:
      consecutive5xxErrors: 1       # Eject after just 1 error
      interval: 1s                  # Check every second
      baseEjectionTime: 3m          # Eject for 3 minutes
      maxEjectionPercent: 100       # Can eject all endpoints if needed
EOF

kubectl apply -f ~/service-mesh-lab/reviews-circuit-breaker.yaml
```

> **Connection pool vs Outlier detection**: Connection pool limits protect the destination from being overwhelmed. Outlier detection removes unhealthy instances from the load balancing pool.

### Circuit Breaker Settings Explained

| Setting | Description |
|---------|-------------|
| `maxConnections` | Maximum number of TCP connections to the service |
| `http1MaxPendingRequests` | Maximum pending HTTP/1.1 requests while waiting for connection |
| `consecutive5xxErrors` | Number of 5xx errors before ejecting endpoint |
| `baseEjectionTime` | How long to remove unhealthy endpoint from pool |
| `maxEjectionPercent` | Maximum percentage of endpoints that can be ejected |

### Test Circuit Breaking

We'll use Fortio, a load testing tool, to generate traffic and trigger the circuit breaker.

```bash
# Deploy a load testing tool (Fortio)
kubectl apply -f samples/httpbin/sample-client/fortio-deploy.yaml

# Wait for fortio to be ready
kubectl wait --for=condition=Ready pod -l app=fortio --timeout=60s

# Send traffic with 2 concurrent connections
# With maxConnections=1, some requests should be rejected
FORTIO_POD=$(kubectl get pods -l app=fortio -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning \
  "http://reviews:9080/reviews/0"
```

> **Expected behavior**: With aggressive limits (maxConnections=1), exceeding concurrency triggers the circuit breaker. You'll see some requests return 503 errors with "upstream connect error or disconnect/reset before headers".

### Check Circuit Breaker Status

View statistics from the Envoy sidecar to see circuit breaker activity.

```bash
# Look for 'overflow' in the stats - indicates circuit breaker triggered
kubectl exec "$FORTIO_POD" -c istio-proxy -- \
  pilot-agent request GET stats | grep reviews | grep pending
```

> **Circuit breaker states**: Open (rejecting requests), Closed (passing requests), Half-Open (testing if service recovered). Istio's circuit breaker is always "closed" but applies limits - it doesn't have distinct states like some implementations.

### Cleanup Circuit Breaker

Remove the aggressive circuit breaker for the next exercises.

```bash
kubectl delete destinationrule reviews-cb
```

---

## Part 10: Fault Injection

**Fault injection** lets you test how your application handles failures without actually breaking anything. It's chaos engineering made safe and controllable through the service mesh.

### Inject Delay Fault

We'll inject a 5-second delay into the ratings service to simulate network latency or a slow database.

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
          value: 100            # Apply to 100% of requests
        fixedDelay: 5s          # Add 5 second delay
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-delay.yaml
```

> **Why inject delays?** Real-world services experience latency spikes. By injecting delays, you can test if your application has proper timeouts, if the UI handles slow responses gracefully, and if monitoring alerts trigger correctly.

### Test Delay Injection

The request should now take ~5 seconds longer due to the injected delay.

```bash
# This should take ~5 seconds due to injected delay
# The 'time' command shows how long the curl took
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by"
```

> **Observation**: Notice the productpage still works, just slowly. This is because the ratings delay affects the reviews service, which affects productpage. Without timeouts, slow dependencies create slow experiences.

### Inject HTTP Abort Fault

Now let's simulate the ratings service returning errors (like database connection failures).

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
          value: 50             # Fail 50% of requests
        httpStatus: 500         # Return HTTP 500 error
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-abort.yaml
```

> **Abort types**: You can inject different HTTP error codes (400, 403, 500, 503, etc.) to test how your app handles various failure modes.

### Test Abort Injection

About half the requests should now show ratings as unavailable.

```bash
# Some requests should fail with errors
# The productpage handles rating failures gracefully, showing "unavailable"
for i in {1..10}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q "Ratings service is currently unavailable" && \
    echo "Request $i: Failed (ratings unavailable)" || echo "Request $i: Success"
  sleep 1
done
```

> **Graceful degradation**: Notice the productpage still works - it just shows "Ratings service unavailable" instead of crashing. Good microservice design handles dependency failures gracefully.

### Cleanup Fault Injection

Remove fault injection for the next exercises.

```bash
kubectl delete virtualservice ratings
```

> **Fault injection best practices**:
> - Start with low percentages (1-5%) in production testing
> - Combine with observability to measure impact
> - Use during chaos engineering experiments
> - Great for testing retry and timeout configurations

---

## Part 11: Request Timeouts and Retries

**Timeouts** prevent requests from waiting forever. **Retries** automatically retry failed requests. Together, they make your system more resilient without changing application code.

### Configure Request Timeout

We configure a 1-second timeout for the reviews service. If reviews takes longer than 1 second, the request fails immediately.

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
  - timeout: 1s                 # Fail if reviews takes longer than 1 second
    route:
    - destination:
        host: reviews
        subset: v2
EOF

kubectl apply -f ~/service-mesh-lab/reviews-timeout.yaml
```

> **Why timeouts matter**: Without timeouts, a slow service can cause thread exhaustion in calling services. One slow service becomes many slow services (cascading failure). Timeouts let you "fail fast" and recover.

### Configure Retries

Retries automatically re-attempt failed requests. This handles transient failures like network blips or temporary pod restarts.

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
      attempts: 3               # Try up to 3 times total
      perTryTimeout: 2s         # Each attempt times out after 2 seconds
      retryOn: 5xx,reset,connect-failure  # Retry on these conditions
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f ~/service-mesh-lab/ratings-retry.yaml
```

> **Retry safety**: Retries are great for read operations (GET requests). Be careful with write operations - you might create duplicate data. Istio's defaults are safe, but you can customize with `retryOn`.

### Retry Configuration Options

| Setting | Description |
|---------|-------------|
| `attempts` | Total number of attempts (original + retries) |
| `perTryTimeout` | Timeout for each individual attempt |
| `retryOn` | Conditions that trigger retry: `5xx`, `reset`, `connect-failure`, `retriable-4xx`, etc. |

> **Common retryOn values**:
> - `5xx`: Retry on 500-599 errors
> - `reset`: Retry when connection is reset
> - `connect-failure`: Retry when connection fails
> - `retriable-4xx`: Retry on 409 (conflict) errors

### Cleanup Timeouts and Retries

Remove the timeout and retry configurations for the next exercises.

```bash
kubectl delete virtualservice reviews ratings
```

> **Best practice**: Set timeouts slightly longer than your P99 latency. Set retry attempts to 2-3 (too many retries can amplify load during outages).

---

## Part 12: Observability - Installing Addons

One of the biggest benefits of service meshes is **observability without code changes**. Because all traffic flows through sidecars, Istio can automatically collect metrics, traces, and logs.

### Install Observability Addons

Istio provides pre-configured observability tools. We'll install the full observability stack.

```bash
cd ~/service-mesh-lab/istio-1.20.0

# Install Kiali, Prometheus, Grafana, and Jaeger
# This creates deployments, services, and configmaps for each tool
kubectl apply -f samples/addons

# Wait for addons to be ready (this may take 2-3 minutes)
kubectl rollout status deployment/kiali -n istio-system
kubectl rollout status deployment/prometheus -n istio-system
kubectl rollout status deployment/grafana -n istio-system
kubectl rollout status deployment/jaeger -n istio-system
```

> **What each tool provides**:
> - **Prometheus**: Metrics collection and storage (requests/sec, latency, errors)
> - **Grafana**: Metrics visualization dashboards
> - **Jaeger**: Distributed tracing (follow requests across services)
> - **Kiali**: Service mesh visualization and management console

### Verify Addon Installation

Confirm all observability pods are running.

```bash
kubectl get pods -n istio-system | grep -E "kiali|prometheus|grafana|jaeger"
```

> **Zero instrumentation**: Notice you didn't add any code to Bookinfo to enable these features. The sidecars automatically emit metrics and propagate trace headers. This works for ANY application in the mesh.

---

## Part 13: Accessing Observability Dashboards

Now let's access the observability tools. Since we're using KIND, we'll use port-forwarding to access the dashboards.

### Access Kiali Dashboard (Service Mesh Visualization)

Kiali provides a visual representation of your service mesh - showing services, their relationships, and traffic flow.

```bash
# In a new terminal, start port forwarding
# The '&' runs this in the background so you can continue using the terminal
kubectl port-forward svc/kiali -n istio-system 20001:20001 &

# Access at http://localhost:20001
echo "Kiali Dashboard: http://localhost:20001"
```

> **Kiali features**:
> - Service graph showing traffic flow between services
> - Health status of services and workloads
> - Configuration validation (finds misconfigurations)
> - Wizards for creating routing rules

### Access Grafana Dashboard (Metrics)

Grafana provides detailed metrics dashboards for latency, error rates, and throughput.

```bash
kubectl port-forward svc/grafana -n istio-system 3000:3000 &

echo "Grafana Dashboard: http://localhost:3000"
```

> **Pre-built dashboards**: Grafana comes with Istio dashboards pre-configured. Look for "Istio Service Dashboard" and "Istio Workload Dashboard" to see detailed metrics.

### Access Jaeger Dashboard (Distributed Tracing)

Jaeger shows distributed traces - following a request as it travels through multiple services.

```bash
kubectl port-forward svc/tracing -n istio-system 16686:80 &

echo "Jaeger Dashboard: http://localhost:16686"
```

> **How tracing works**: Istio automatically injects trace headers into requests. As a request flows through services (productpage → reviews → ratings), each hop is recorded. Jaeger visualizes this journey.

### Generate Traffic for Visualization

The dashboards need traffic data to display. Let's generate some requests.

```bash
# Generate traffic for observability tools
# This creates data for metrics and traces
echo "Generating traffic for 60 seconds..."
for i in {1..60}; do
  curl -s -o /dev/null "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
  sleep 1
done
echo "Traffic generation complete!"
```

> **Tip**: While traffic is generating, open Kiali and watch the service graph animate with live traffic flow!

### View Istio Metrics

Prometheus is the metrics backend. You can query raw metrics here.

```bash
# View metrics in Prometheus
kubectl port-forward svc/prometheus -n istio-system 9090:9090 &

# Query example: istio_requests_total
echo "Prometheus: http://localhost:9090"
```

> **Useful Prometheus queries**:
> - `istio_requests_total` - Total request count
> - `istio_request_duration_milliseconds` - Request latency
> - `istio_tcp_connections_opened_total` - TCP connections

### Stop Port Forwarding

When you're done exploring the dashboards, stop the port-forward processes.

```bash
# Stop all port forwards when done
pkill -f "port-forward"
```

---

## Part 14: Authorization Policies

**Authorization policies** control which services can talk to which. This is zero-trust networking at the service level - every connection must be explicitly allowed.

### Deny All Traffic by Default

We start by implementing a zero-trust baseline: deny all traffic by default. This is the most secure starting point.

```bash
cat > ~/service-mesh-lab/deny-all.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}  # Empty spec with no rules = deny everything
EOF

kubectl apply -f ~/service-mesh-lab/deny-all.yaml

# Test - should fail with 403 Forbidden
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

Expected output: `403` (Forbidden)

> **Zero-trust principle**: With deny-all, no service can communicate unless explicitly allowed. This prevents lateral movement if an attacker compromises one service.

### Allow Specific Traffic

Now we selectively allow traffic to productpage from the ingress gateway and from within the default namespace.

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
      app: productpage              # This policy applies to productpage pods
  action: ALLOW
  rules:
  # Rule 1: Allow traffic from the ingress gateway (external users)
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
  # Rule 2: Allow traffic from any service in the default namespace
  - from:
    - source:
        namespaces: ["default"]
EOF

kubectl apply -f ~/service-mesh-lab/allow-productpage.yaml
```

> **Principal-based authorization**: The `principals` field uses the service account identity from the mTLS certificate. This is cryptographically verified - you can't spoof it!

### Allow Internal Service Communication

Each service needs explicit permission to call other services. This creates the minimum required access.

```bash
cat > ~/service-mesh-lab/allow-internal.yaml <<'EOF'
# Allow productpage to call details
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
        # Only productpage can call details
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
---
# Allow productpage to call reviews
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
        # Only productpage can call reviews
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
---
# Allow reviews to call ratings
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
        # Only reviews can call ratings
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
EOF

kubectl apply -f ~/service-mesh-lab/allow-internal.yaml
```

> **Least privilege**: Notice ratings can ONLY be called by reviews. If a compromised productpage tries to call ratings directly, it will be blocked!

### Test Authorization Policies

With all policies in place, the application should work again.

```bash
# Should now work with policies in place
curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
```

Expected output: `200`

> **Policy evaluation**: Istio evaluates policies as: 1) If DENY policy matches, deny. 2) If no ALLOW policies exist, allow. 3) If ALLOW policies exist, must match one to allow.

### Cleanup Authorization Policies

Remove authorization policies for the next exercises.

```bash
kubectl delete authorizationpolicy deny-all allow-productpage allow-details allow-reviews allow-ratings
```

> **Production recommendation**: Always start with deny-all and explicitly allow required communication. This makes your security posture clear and auditable.

---

## Scenario-Based Exercises: Deploying "TechShop" Microservices Platform

Now that you understand the individual components, let's apply them in realistic scenarios. These exercises simulate real-world problems you'll encounter as a Platform Engineer.

You've been hired as a Platform Engineer at **TechShop**, an e-commerce company migrating to microservices. Your mission: implement a service mesh to improve security, observability, and traffic management.

> **Story Context**: TechShop had a major outage last month because one failing service caused cascading failures. The CTO has mandated implementing a service mesh to prevent this from happening again.

Each exercise builds on concepts from the previous parts and combines multiple features to solve real problems.

```bash
# Setup: Create your workspace
cd ~/service-mesh-lab
```

---

### Exercise 1: The Cascading Failure Problem

**Scenario**: Before implementing the service mesh, let's understand the problem. When the ratings service becomes slow, the entire application hangs. This is the #1 cause of cascading failures in microservices.

**Your Task**: Demonstrate the cascading failure problem and then solve it with Istio.

**What you'll learn**: How a single slow service can bring down your entire application, and how timeouts prevent this.

#### Step 1: Create the Problem (Inject Delay)

First, we'll use Istio's fault injection to simulate a slow ratings service. This is safer than actually breaking the service!

```bash
# First, reset to baseline routing (all traffic to v1)
# This ensures we have a clean starting point
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/bookinfo/networking/virtual-service-all-v1.yaml

# Inject a 10-second delay in ratings
# This simulates a database timeout or network issue
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
          value: 100        # 100% of requests affected
        fixedDelay: 10s     # Each request delayed 10 seconds
    route:
    - destination:
        host: ratings
        subset: v1
EOF

kubectl apply -f exercise-delay.yaml
```

> **Real-world parallel**: This simulates a database connection timeout, a network partition, or a resource exhaustion issue - all common production problems.

#### Step 2: Observe the Problem

Now watch how a slow ratings service affects the entire application.

```bash
echo "Without timeout protection, requests hang for 10+ seconds..."
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by"
```

> **Observation**: The entire page load takes 10+ seconds because:
> 1. productpage calls reviews
> 2. reviews calls ratings (which is slow)
> 3. reviews waits for ratings (no timeout!)
> 4. productpage waits for reviews
> 5. User waits for productpage
> 
> This is a **cascading delay** - one slow service makes everything slow.

#### Step 3: Implement the Solution (Timeout)

Now we add a timeout to the reviews service. If ratings doesn't respond in 3 seconds, reviews gives up.

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
  - timeout: 3s                 # Give up after 3 seconds
    route:
    - destination:
        host: reviews
        subset: v1
EOF

kubectl apply -f exercise-timeout-fix.yaml
```

> **Why 3 seconds?** You want a timeout longer than normal response time but short enough to fail fast. In production, base this on your P99 latency + buffer.

#### Step 4: Verify the Fix

The request should now fail fast (~3 seconds) instead of hanging for 10+ seconds.

```bash
echo "With timeout, requests fail fast instead of hanging..."
time curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -o "Reviews served by\|Sorry"
```

> **Result**: The page loads in ~3 seconds. The reviews section may show an error, but the page is usable! This is graceful degradation - better to show partial content than hang forever.

**📝 Key Learning**: Service meshes provide timeout protection that prevents cascading failures! One slow service no longer brings down your entire application.

#### Step 5: Cleanup Exercise 1

Remove the exercise configurations to prepare for the next exercise.

```bash
kubectl delete virtualservice ratings reviews
rm exercise-delay.yaml exercise-timeout-fix.yaml
```

---

### Exercise 2: Safe Canary Deployment

**Scenario**: The development team has a new version of the reviews service (v3 with red stars). You need to safely roll it out to 10% of users first, then gradually increase. If anything goes wrong, you need instant rollback capability.

**Your Task**: Implement a canary deployment with traffic shifting.

**What you'll learn**: How to gradually roll out new versions while minimizing risk.

#### Step 1: Verify Current Routing

First, establish a baseline: 100% traffic to the stable version (v1). This is your "safe state" to roll back to if needed.

```bash
# Apply destination rules if not present
# These define the subsets (v1, v2, v3) based on pod labels
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/bookinfo/networking/destination-rule-all.yaml

# Route all traffic to v1 (baseline)
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
      weight: 100              # All traffic to stable version
EOF

kubectl apply -f exercise-canary-v1.yaml
echo "Currently: 100% v1"
```

> **Why start here?** In production, you'd already have this baseline. Establishing 100% v1 ensures we know what "working" looks like before making changes.

#### Step 2: Start Canary (10% to v3)

Now we divert a small percentage (10%) to the new version. This limits blast radius - if v3 has issues, only 10% of users are affected.

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
      weight: 90               # 90% to stable
    - destination:
        host: reviews
        subset: v3
      weight: 10               # 10% to canary (new version)
EOF

kubectl apply -f exercise-canary-10.yaml
echo "Canary started: 90% v1, 10% v3"
```

> **Production workflow**: At this point, you'd monitor error rates, latency, and user feedback for v3. If metrics look good, proceed. If not, instantly rollback by applying the 100% v1 config.

#### Step 3: Test the Canary Distribution

Let's verify the traffic split is working. With 10% to v3, we expect roughly 2 out of 20 requests to show red stars.

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

> **Note**: Due to randomness, you might not see exactly 10%. Over many requests, the distribution converges to the configured weights.

#### Step 4: Increase to 50%

Metrics look good! Let's increase traffic to v3. This is the "gaining confidence" phase.

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
      weight: 50               # Equal split
    - destination:
        host: reviews
        subset: v3
      weight: 50
EOF

kubectl apply -f exercise-canary-50.yaml
echo "Increased: 50% v1, 50% v3"
```

> **Typical canary progression**: 1% → 5% → 10% → 25% → 50% → 100%, with monitoring at each stage. Speed depends on traffic volume and confidence.

#### Step 5: Complete Migration

Everything looks good! Complete the migration by sending 100% to v3.

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
      weight: 100              # Full migration complete
EOF

kubectl apply -f exercise-canary-full.yaml
echo "Migration complete: 100% v3"

# Verify all requests now go to v3
for i in {1..5}; do
  curl -s "http://$INGRESS_HOST:$INGRESS_PORT/productpage" | grep -q 'font color="red"' && \
    echo "Request $i: v3 ✓" || echo "Request $i: unexpected"
done
```

> **Post-migration**: v1 pods are still running! If issues emerge, you can instantly rollback. After a "bake time" (e.g., 24 hours), you can safely scale down v1.

**📝 Key Learning**: Service meshes enable zero-downtime canary deployments with precise traffic control! No code changes, no downtime, instant rollback capability.

#### Step 6: Cleanup Exercise 2

Remove exercise files to prepare for the next exercise.

```bash
kubectl delete virtualservice reviews
rm exercise-canary-*.yaml
```

---

### Exercise 3: Implementing Zero-Trust Security

**Scenario**: The security team requires all service-to-service communication to be encrypted and authenticated. A recent security audit found plaintext traffic between services - unacceptable for PCI compliance. Implement strict mTLS.

**Your Task**: Enable strict mTLS and verify secure communication.

**What you'll learn**: How to implement zero-trust networking where every connection is encrypted and authenticated.

#### Step 1: Check Current Security Mode

First, check the current mTLS status. By default, Istio uses PERMISSIVE mode (accepts both encrypted and plaintext).

```bash
echo "Current mTLS status:"
kubectl get peerauthentication --all-namespaces
```

> **Expected result**: If empty, you're using the default (PERMISSIVE). This allows gradual migration but doesn't enforce encryption.

#### Step 2: Enable Strict mTLS

Now we enforce that all traffic MUST be encrypted with mTLS. Any plaintext connections will be rejected.

```bash
cat > exercise-mtls-strict.yaml <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default           # Applies to all workloads in this namespace
spec:
  mtls:
    mode: STRICT               # Reject any non-mTLS traffic
EOF

kubectl apply -f exercise-mtls-strict.yaml
echo "Strict mTLS enabled!"
```

> **What changes**: All services in the default namespace now REQUIRE mTLS. The sidecars automatically handle the encryption - your application code doesn't change at all!

#### Step 3: Verify mTLS is Working

Verify the application still works (now all internal traffic is encrypted).

```bash
# Check that the application still works (all traffic now encrypted)
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"

# View TLS certificates issued to the service
# Each workload gets a unique identity certificate
echo ""
echo "Service certificates:"
istioctl proxy-config secret "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" \
  -o json | grep -E "serialNumber|validityDuration" | head -6
```

> **Transparent encryption**: The application still uses `http://` internally. The sidecars transparently upgrade all connections to mTLS. Your code never knows!

#### Step 4: Test that Non-mTLS Traffic is Blocked

Now let's prove that STRICT mode actually blocks unencrypted traffic. We'll deploy a pod WITHOUT a sidecar and try to connect.

```bash
# Deploy a pod without sidecar (using a namespace without injection)
# This simulates a rogue pod or a pod from before the mesh was enabled
kubectl run test-no-mesh --image=busybox --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/test-no-mesh --timeout=30s

# Try to access services from outside the mesh
# This should FAIL because the pod can't provide mTLS credentials
kubectl exec test-no-mesh -- wget -qO- http://reviews:9080/reviews/0 2>&1 | head -5 || echo "Connection blocked (expected with STRICT mTLS)"

# Cleanup test pod
kubectl delete pod test-no-mesh --wait=false
```

> **Security verification**: The connection fails! Without the sidecar (which provides the mTLS certificate), the pod cannot authenticate to mesh services. This is zero-trust in action.

**📝 Key Learning**: Service meshes provide transparent mTLS encryption without application changes! All service-to-service communication is now encrypted and authenticated.

#### Step 5: Cleanup Exercise 3

Remove the strict mTLS policy for the next exercise.

```bash
kubectl delete peerauthentication default
rm exercise-mtls-strict.yaml
```

---

### Exercise 4: Implementing Resilience Patterns

**Scenario**: During peak traffic (Black Friday sale), the ratings service sometimes becomes overloaded. When this happens, requests pile up, memory fills, and eventually the service crashes. This creates a cascading failure affecting all dependent services.

**Your Task**: Configure circuit breaking to prevent cascading failures under load.

**What you'll learn**: How circuit breakers protect services from being overwhelmed and how to "fail fast" during overload.

#### Step 1: Configure Circuit Breaker

We'll configure aggressive limits to demonstrate circuit breaking. In production, you'd tune these based on actual service capacity.

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
        maxConnections: 1           # Only 1 TCP connection allowed
      http:
        http1MaxPendingRequests: 1  # Only 1 request can queue
        maxRequestsPerConnection: 1 # Close connection after each request
    outlierDetection:
      consecutive5xxErrors: 2       # Eject after 2 consecutive errors
      interval: 10s                 # Check health every 10 seconds
      baseEjectionTime: 30s         # Remove from pool for 30 seconds
      maxEjectionPercent: 100       # Can eject all instances if needed
EOF

kubectl apply -f exercise-circuit-breaker.yaml
echo "Circuit breaker configured!"
```

> **Two protection mechanisms**:
> - **connectionPool**: Limits concurrent connections/requests (prevents overload)
> - **outlierDetection**: Removes unhealthy instances from load balancing pool

#### Step 2: Deploy Load Testing Tool

We'll use Fortio, a load testing tool, to generate controlled traffic.

```bash
# Deploy Fortio load testing pod
kubectl apply -f ~/service-mesh-lab/istio-1.20.0/samples/httpbin/sample-client/fortio-deploy.yaml
kubectl wait --for=condition=Ready pod -l app=fortio --timeout=60s
```

> **Why Fortio?** It allows precise control over concurrency, QPS, and request count - essential for testing circuit breakers.

#### Step 3: Test Normal Load

First, test with low concurrency (within our limits) to establish baseline.

```bash
echo "Testing with 2 concurrent connections (within limits)..."
FORTIO_POD=$(kubectl get pods -l app=fortio -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 2 -qps 0 -n 10 -loglevel Warning \
  "http://ratings:9080/ratings/0" 2>&1 | grep "Code"
```

> **Expected result**: Most/all requests succeed (Code 200). With only 2 concurrent connections and limit of 1, some may fail but it's manageable.

#### Step 4: Test Overload (Trip Circuit)

Now blast the service with high concurrency to trigger the circuit breaker.

```bash
echo "Testing with 10 concurrent connections (exceeds limits)..."
kubectl exec "$FORTIO_POD" -c fortio -- \
  /usr/bin/fortio load -c 10 -qps 0 -n 50 -loglevel Warning \
  "http://ratings:9080/ratings/0" 2>&1 | grep -E "Code|overflow"
```

You should see some requests returning 503 (overflow) - the circuit breaker in action!

> **What you see**: Some requests get 200 (success), others get 503 (circuit breaker rejected them). This is intentional! Instead of all requests piling up and crashing the service, excess load is immediately rejected. The service stays healthy for requests that do get through.

**📝 Key Learning**: Circuit breakers prevent service overload by failing fast when limits are exceeded! This protects the destination service and gives clear feedback to callers to back off.

#### Step 5: Cleanup Exercise 4

Remove the circuit breaker and load testing tool.

```bash
kubectl delete destinationrule ratings-circuit-breaker
kubectl delete -f ~/service-mesh-lab/istio-1.20.0/samples/httpbin/sample-client/fortio-deploy.yaml
rm exercise-circuit-breaker.yaml
```

---

### Exercise 5: Observability Challenge

**Scenario**: The operations team needs visibility into service communication patterns, latencies, and error rates. After last month's outage, the CTO wants real-time dashboards showing what's happening in the mesh.

**Your Task**: Use Istio's observability tools to analyze the service mesh.

**What you'll learn**: How to gain visibility into your microservices without adding any instrumentation code.

#### Step 1: Generate Traffic

First, generate some traffic so we have data to analyze.

```bash
echo "Generating traffic for analysis..."
for i in {1..30}; do
  # Each request creates metrics and trace data
  curl -s -o /dev/null "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
  sleep 0.5
done
echo "Traffic generated!"
```

> **What's being collected**: Every request automatically generates metrics (latency, status codes, sizes) and distributed traces (request path through services).

#### Step 2: View Proxy Statistics

Each Envoy sidecar collects detailed statistics. Let's examine them directly.

```bash
# View Envoy stats for productpage
# These show real metrics collected by the sidecar
echo "=== Productpage Proxy Stats ==="
kubectl exec "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" \
  -c istio-proxy -- pilot-agent request GET stats | grep -E "upstream_rq_total|upstream_rq_2xx" | head -10
```

> **What you see**: 
> - `upstream_rq_total`: Total requests made to upstream services
> - `upstream_rq_2xx`: Successful requests (200-299 status codes)
> - Each line shows metrics for a specific upstream cluster (reviews, details, etc.)

#### Step 3: View Service Mesh Configuration

Get an overview of all Istio configurations currently active.

```bash
# View all Istio configurations
echo ""
echo "=== Istio Configuration Summary ==="

echo "VirtualServices (routing rules):"
kubectl get virtualservices

echo ""
echo "DestinationRules (traffic policies):"
kubectl get destinationrules

echo ""
echo "Gateways (ingress configuration):"
kubectl get gateways

echo ""
echo "PeerAuthentication (mTLS policies):"
kubectl get peerauthentication --all-namespaces
```

> **Configuration audit**: This view shows what's active in your mesh. In production, you'd track these in Git for change management.

#### Step 4: Analyze with istioctl

`istioctl analyze` is your friend - it finds misconfigurations and issues.

```bash
# Analyze the mesh for issues
# This catches common mistakes like missing DestinationRules, conflicting policies, etc.
echo ""
echo "=== Mesh Analysis ==="
istioctl analyze

# View service dependencies from the proxy's perspective
# This shows what services productpage can talk to
echo ""
echo "=== Proxy Config for productpage ==="
istioctl proxy-config clusters "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" | head -15
```

> **Pro tip**: Run `istioctl analyze` after any configuration change. It catches issues like "VirtualService references subset that doesn't exist in DestinationRule" before they cause problems.

**📝 Key Learning**: Service meshes provide rich observability without code changes! Metrics, traces, and logs are automatically collected for every request in the mesh.

---

### Final Exercise: Complete Cleanup and Review

Let's review what we've built and summarize the key learnings before cleanup.

#### Step 1: Review All Resources

View all the components we've deployed and configured throughout the lab.

```bash
echo "╔════════════════════════════════════════════════╗"
echo "║   Service Mesh Lab Resources Summary           ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Istio Components (Control Plane):"
kubectl get pods -n istio-system | head -10
echo ""
echo "Bookinfo Application (Data Plane):"
kubectl get pods -l app
echo ""
echo "Istio Custom Resources (Configuration):"
kubectl get virtualservices,destinationrules,gateways
```

> **Architecture review**: You now have:
> - **Control Plane** (istio-system): istiod managing configuration
> - **Data Plane** (default): Application pods with Envoy sidecars
> - **Configuration**: CRDs defining routing, policies, and gateways

#### Step 2: Key Takeaways Summary

Reflect on what you've learned and accomplished.

```bash
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║          🎓 LAB COMPLETE - KEY TAKEAWAYS 🎓            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Exercise 1: Timeout Protection"
echo "   → Prevents cascading failures from slow services"
echo "   → Key: VirtualService with 'timeout' field"
echo ""
echo "✅ Exercise 2: Canary Deployments"
echo "   → Safe, gradual rollouts with traffic shifting"
echo "   → Key: VirtualService with 'weight' on routes"
echo ""
echo "✅ Exercise 3: Zero-Trust Security"
echo "   → Automatic mTLS encryption between services"
echo "   → Key: PeerAuthentication with mode: STRICT"
echo ""
echo "✅ Exercise 4: Circuit Breaking"
echo "   → Fail fast to prevent service overload"
echo "   → Key: DestinationRule with connectionPool/outlierDetection"
echo ""
echo "✅ Exercise 5: Observability"
echo "   → Built-in metrics, tracing, and visualization"
echo "   → Key: Zero code changes - sidecars collect everything"
echo ""
echo "🚀 You now understand service mesh fundamentals!"
echo "════════════════════════════════════════════════════════"
```

> **Next steps**: In production, you'd combine these features. For example:
> - Canary deployment + observability = watch error rates during rollout
> - mTLS + authorization policies = complete zero-trust security
> - Timeouts + circuit breaking + retries = resilient services

---

## Key Takeaways

This section summarizes the most important concepts from the lab.

### Service Mesh Fundamentals

| Concept | What You Learned |
|---------|------------------|
| **Service Mesh** | A dedicated infrastructure layer for service-to-service communication |
| **Data Plane** | Envoy sidecars that intercept and handle all traffic |
| **Control Plane** | istiod that manages configuration and certificates |
| **Sidecar Injection** | Automatic proxy injection via namespace labels |

> **Key insight**: Service mesh moves cross-cutting concerns (security, observability, traffic control) from application code to infrastructure.

### Traffic Management

| Feature | Use Case | Key Configuration |
|---------|----------|-------------------|
| **VirtualService** | Route traffic, split weights, match headers | `route.destination.subset`, `weight` |
| **DestinationRule** | Define subsets, connection pools | `subsets`, `trafficPolicy` |
| **Traffic Shifting** | Canary deployments, A/B testing | VirtualService weights |
| **Fault Injection** | Chaos engineering, resilience testing | `fault.delay`, `fault.abort` |

> **Key insight**: All traffic control is declarative YAML - no code changes, instant rollback capability.

### Security

| Feature | Use Case | Key Configuration |
|---------|----------|-------------------|
| **mTLS** | Encrypt all service-to-service traffic | Automatic with sidecars |
| **PeerAuthentication** | Enforce encryption mode | `mtls.mode: STRICT` |
| **AuthorizationPolicy** | Control who can call what | `rules.from.source.principals` |

> **Key insight**: Zero-trust security is achievable without touching application code. Certificates are automatically provisioned and rotated.

### Resilience

| Feature | Problem It Solves | Key Configuration |
|---------|-------------------|-------------------|
| **Timeouts** | Hanging requests, cascading delays | VirtualService `timeout` |
| **Retries** | Transient failures | VirtualService `retries` |
| **Circuit Breaking** | Service overload | DestinationRule `connectionPool` |
| **Outlier Detection** | Unhealthy instances | DestinationRule `outlierDetection` |

> **Key insight**: Resilience patterns that would require libraries like Hystrix are now declarative infrastructure configuration.

### Observability

| Tool | What It Provides | Access |
|------|------------------|--------|
| **Kiali** | Service graph, traffic visualization | Port 20001 |
| **Jaeger** | Distributed tracing | Port 16686 |
| **Grafana** | Metrics dashboards | Port 3000 |
| **Prometheus** | Raw metrics, alerting | Port 9090 |

> **Key insight**: Full observability with zero instrumentation. Sidecars automatically collect metrics and propagate trace headers.

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

When you're done with the lab, clean up all resources to free cluster resources. Follow these steps in order.

### Step 1: Delete the Sample Application

Remove the Bookinfo application and its Istio configurations.

```bash
cd ~/service-mesh-lab/istio-1.20.0

# Delete Bookinfo application (Deployments, Services, ServiceAccounts)
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml

# Delete Bookinfo gateway and routing
kubectl delete -f samples/bookinfo/networking/bookinfo-gateway.yaml

# Delete destination rules
kubectl delete -f samples/bookinfo/networking/destination-rule-all.yaml
```

### Step 2: Delete Observability Addons

Remove Kiali, Prometheus, Grafana, and Jaeger.

```bash
# Delete observability addons
kubectl delete -f samples/addons
```

### Step 3: Clean Up Any Remaining Istio Resources

Remove any VirtualServices, DestinationRules, etc. created during exercises.

```bash
# Delete any remaining Istio custom resources
kubectl delete virtualservices --all
kubectl delete destinationrules --all
kubectl delete gateways --all
kubectl delete peerauthentication --all
kubectl delete authorizationpolicies --all
```

### Step 4: Uninstall Istio

Remove Istio control plane components.

```bash
# Uninstall Istio completely
istioctl uninstall --purge -y

# Delete the istio-system namespace
kubectl delete namespace istio-system

# Remove istio-injection label from default namespace
kubectl label namespace default istio-injection-
```

### Step 5: Remove Lab Directory

Clean up local files.

```bash
cd ~
rm -rf ~/service-mesh-lab
```

### Step 6: Verify Cleanup

Confirm everything is removed.

```bash
# Should show no pods (or only system pods)
kubectl get pods

# Should not show istio namespace
kubectl get ns | grep istio

# Should show no Istio CRDs
kubectl get crds | grep istio
```

> **Note**: If you want to keep the KIND cluster for other labs, skip this. If you want a completely fresh start, you can delete and recreate the KIND cluster using `kind delete cluster && kind create cluster`.

---

## Troubleshooting Common Issues

This section covers the most common problems you'll encounter and how to diagnose them.

### Sidecar Not Injected

**Symptom**: Pods show `1/1` Ready instead of `2/2`. No Envoy sidecar present.

**Cause**: Namespace not labeled for injection, or pods created before labeling.

```bash
# Check namespace label
kubectl get namespace default --show-labels | grep istio-injection

# If missing, add it
kubectl label namespace default istio-injection=enabled

# Existing pods need to be recreated - restart deployments
kubectl rollout restart deployment --all
```

> **Why restart?** Sidecar injection happens at pod creation time. Existing pods won't get sidecars retroactively.

### Gateway Not Accessible

**Symptom**: Can't reach the application through the ingress gateway. Connection refused or timeout.

**Cause**: Gateway misconfiguration, VirtualService not bound to gateway, or port issues.

```bash
# Check ingress gateway pods are running
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Check gateway configuration - ensure hosts match
kubectl describe gateway bookinfo-gateway

# Check VirtualService has 'gateways' field binding to the gateway
kubectl get virtualservice -o yaml | grep -A 5 gateways

# Verify ports - note the NodePort for http2
kubectl get svc istio-ingressgateway -n istio-system
```

> **Common fix**: Ensure VirtualService includes `gateways: [bookinfo-gateway]` field.

### Traffic Not Routing as Expected

**Symptom**: Traffic doesn't follow VirtualService rules. Wrong version served.

**Cause**: Missing DestinationRule, mismatched subset names, or pod label issues.

```bash
# Analyze the mesh for configuration issues
istioctl analyze

# Check VirtualService configuration
kubectl describe virtualservice <name>

# Verify DestinationRule subsets exist and match pod labels
kubectl get destinationrule -o yaml | grep -A 5 subsets
kubectl get pods --show-labels | grep version

# Check what the proxy actually has configured
istioctl proxy-config routes <pod-name>
```

> **Common fix**: Ensure DestinationRule defines subsets that match the `version` labels on your pods.

### mTLS Issues

**Symptom**: Connections fail with "connection reset" or "TLS handshake error".

**Cause**: Mixed mTLS modes, missing certificates, or non-mesh clients trying to connect in STRICT mode.

```bash
# Check PeerAuthentication policies
kubectl get peerauthentication --all-namespaces

# Check destination rule TLS settings (shouldn't conflict with PeerAuthentication)
kubectl get destinationrule -o yaml | grep -A 5 tls

# Verify certificates are present and valid
istioctl proxy-config secret <pod-name>
```

> **Common fix**: In STRICT mode, all clients must have sidecars. Use PERMISSIVE during migration.

### Pods Crashing After Istio Installation

**Symptom**: Pods in CrashLoopBackOff or Error state after enabling Istio.

**Cause**: Init container failures, resource limits, or application conflicts with sidecar.

```bash
# Check pod events for clues
kubectl describe pod <pod-name>

# Check istio-proxy container logs
kubectl logs <pod-name> -c istio-proxy

# Check istio-init container logs (runs at startup)
kubectl logs <pod-name> -c istio-init

# Check istiod logs for injection/configuration issues
kubectl logs -n istio-system -l app=istiod
```

> **Common causes**:
> - Insufficient memory (sidecar needs ~100Mi)
> - App using iptables (conflicts with sidecar)
> - App binding to 127.0.0.1 (sidecar can't intercept)

### Observability Tools Not Working

**Symptom**: Can't access Kiali, Grafana, Jaeger dashboards or they show no data.

**Cause**: Addon pods not running, services not exposed, or no traffic generated.

```bash
# Check addon pods are running
kubectl get pods -n istio-system | grep -E "kiali|prometheus|grafana|jaeger"

# Check addon services exist
kubectl get svc -n istio-system | grep -E "kiali|prometheus|grafana|tracing"

# Restart if pods are stuck
kubectl rollout restart deployment kiali -n istio-system
kubectl rollout restart deployment prometheus -n istio-system
kubectl rollout restart deployment grafana -n istio-system
```

> **No data in dashboards?** Generate some traffic first! Dashboards need requests to display metrics and traces.

---

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Istio Observability](https://istio.io/latest/docs/concepts/observability/)
- [Bookinfo Sample Application](https://istio.io/latest/docs/examples/bookinfo/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs/)

