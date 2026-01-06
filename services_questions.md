# Kubernetes Services – Test Questions

Use these questions to assess participant understanding after completing the Kubernetes Services lab.

---

## Section 1: Multiple Choice

**1. What is the primary purpose of a Kubernetes Service?**

a) To store application data  
b) To provide stable networking and service discovery for Pods  
c) To schedule Pods on nodes  
d) To manage container images  

---

**2. What is the default Service type when none is specified?**

a) NodePort  
b) LoadBalancer  
c) ClusterIP  
d) ExternalName  

---

**3. Which Service type exposes the service on each node's IP at a static port?**

a) ClusterIP  
b) NodePort  
c) ExternalName  
d) Headless  

---

**4. What is the valid port range for NodePort services?**

a) 1-65535  
b) 80-443  
c) 30000-32767  
d) 8000-9000  

---

**5. What DNS name can a Pod use to access a service named `api` in the same namespace?**

a) `api.cluster.local`  
b) `api`  
c) `api.svc.cluster.local`  
d) `svc.api`  

---

**6. What is the fully qualified DNS name for a service named `backend` in namespace `production`?**

a) `backend.production`  
b) `backend.production.svc.cluster.local`  
c) `production.backend.svc.cluster.local`  
d) `backend.svc.production.cluster.local`  

---

**7. What object does Kubernetes automatically create to track the IP addresses of Pods matching a Service's selector?**

a) ConfigMap  
b) Endpoints  
c) PodList  
d) ServiceAccount  

---

**8. What makes a Service "headless"?**

a) Setting `type: Headless`  
b) Setting `clusterIP: None`  
c) Removing all ports  
d) Setting `selector: none`  

---

**9. When would you use a selector-less Service?**

a) When you don't want load balancing  
b) When connecting to resources outside the Kubernetes cluster  
c) When using StatefulSets  
d) When the application doesn't have labels  

---

**10. What type of DNS record does an ExternalName Service create?**

a) A record  
b) AAAA record  
c) CNAME record  
d) SRV record  

---

**11. What happens to a Pod's traffic when its readiness probe fails?**

a) The Pod is deleted  
b) The Pod is restarted  
c) The Pod is removed from Service endpoints  
d) Nothing changes  

---

**12. Which command creates a Service for an existing Deployment named `web`?**

a) `kubectl create service web`  
b) `kubectl expose deployment web`  
c) `kubectl service create web`  
d) `kubectl apply service web`  

---

**13. What does `sessionAffinity: ClientIP` configure?**

a) Routes all traffic to a single Pod  
b) Routes requests from the same client IP to the same Pod  
c) Assigns a static IP to the client  
d) Enables sticky sessions with cookies  

---

**14. In the Service spec, what does `targetPort` represent?**

a) The port the Service listens on  
b) The port on the Pod where traffic is forwarded  
c) The NodePort value  
d) The external load balancer port  

---

**15. What is required when a Service exposes multiple ports?**

a) Each port must have a unique protocol  
b) Each port must have a `name`  
c) The Service must be of type NodePort  
d) Multiple selectors must be defined  

---

**16. How can you view the Pod IPs that a Service routes traffic to?**

a) `kubectl get pods -o wide`  
b) `kubectl get endpoints <service-name>`  
c) `kubectl describe pod`  
d) `kubectl get svc -o yaml`  

---

**17. What is the main advantage of using DNS for service discovery over environment variables?**

a) DNS is faster  
b) Services don't need to exist before Pods start  
c) DNS provides encryption  
d) Environment variables don't work in containers  

---

**18. Which Service type would you use to create a DNS alias for an external API at `api.external.com`?**

a) ClusterIP  
b) NodePort  
c) LoadBalancer  
d) ExternalName  

---

**19. What command shows the selector used by a Service?**

a) `kubectl get pods -l selector`  
b) `kubectl get svc <name> -o wide`  
c) `kubectl describe nodes`  
d) `kubectl get endpoints`  

---

**20. If a Service has `port: 8080` and `targetPort: 80`, what port do applications use to access the Service?**

a) 80  
b) 8080  
c) Both 80 and 8080  
d) Neither; an error occurs  

---

## Section 2: True or False

**21. A ClusterIP Service can be accessed from outside the Kubernetes cluster.**

☐ True  
☐ False  

---

**22. NodePort Services also get a ClusterIP address.**

☐ True  
☐ False  

---

**23. Kubernetes automatically updates Endpoints when Pods are added or removed.**

☐ True  
☐ False  

---

**24. A headless Service provides load balancing across Pods.**

☐ True  
☐ False  

---

**25. Services can only select Pods using a single label.**

☐ True  
☐ False  

---

**26. Environment variables for Services are updated when Services change.**

☐ True  
☐ False  

---

**27. Pods failing readiness probes are automatically removed from Service Endpoints.**

☐ True  
☐ False  

---

**28. ExternalName Services can point to IP addresses.**

☐ True  
☐ False  

---

**29. The same Service can have both ClusterIP and NodePort access simultaneously.**

☐ True  
☐ False  

---

**30. Services can route traffic to Pods in different namespaces.**

☐ True  
☐ False  

---

## Section 3: Fill in the Blank

**31. Complete the command to create a NodePort Service for a deployment named `webapp`:**

```bash
kubectl expose deployment webapp --type=__________
```

---

**32. Complete the Service spec to make it headless:**

```yaml
spec:
  clusterIP: __________
  selector:
    app: myapp
```

---

**33. Complete the DNS name to access a service named `api` in namespace `backend`:**

```
api.__________
```

---

**34. Complete the command to view the Endpoints for a service named `frontend`:**

```bash
kubectl get __________ frontend
```

---

**35. In a Service spec, the __________ field determines which Pods receive traffic.**

---

**36. Complete the Service spec to enable session affinity:**

```yaml
spec:
  sessionAffinity: __________
```

---

**37. Complete the command to create a service exposing port 80 and targeting port 8080:**

```bash
kubectl expose deployment web --port=80 --target-port=__________
```

---

**38. The default session affinity for a Service is __________.**

---

**39. Complete the ExternalName Service spec:**

```yaml
spec:
  type: ExternalName
  externalName: __________
```

---

**40. To access a service from another namespace, you must include the __________ in the DNS name.**

---

## Section 4: Short Answer

**41. Explain the difference between ClusterIP and NodePort Service types. When would you use each?**

---

**42. What are Endpoints in Kubernetes and how do they relate to Services?**

---

**43. Describe a scenario where you would use a selector-less Service with manual Endpoints.**

---

**44. Explain how headless Services differ from regular Services and provide a use case.**

---

**45. Why is DNS-based service discovery preferred over environment variables?**

---

**46. A developer reports that their Service is not routing traffic to any Pods. List the troubleshooting steps you would take.**

---

**47. Explain the relationship between Services, readiness probes, and Endpoints.**

---

**48. What are the limitations of using ExternalName Services?**

---

## Section 5: Practical Scenarios

**49. Write a complete YAML manifest for:**
- A Deployment named `api-server` with 3 replicas using image `nginx:alpine` on port 80
- A ClusterIP Service named `api` routing port 8080 to the deployment

---

**50. Write the commands to:**
1. Create a deployment named `web` with 2 replicas
2. Expose it as a NodePort service on port 30100
3. Verify the service and endpoints
4. Test connectivity from within the cluster

---

**51. Write a YAML manifest for a selector-less Service and Endpoints pointing to external IPs 10.0.0.50 and 10.0.0.51 on port 3306.**

---

**52. Write the commands to:**
1. Create two namespaces: `frontend` and `backend`
2. Deploy an application in each namespace
3. Create services for both
4. Test cross-namespace connectivity

---

**53. Write a YAML manifest for a headless Service that will return all Pod IPs for an application labeled `app=database`.**

---

**54. A team needs to migrate from an external database to one running in Kubernetes. Describe the steps using Services to ensure zero application changes.**

---

**55. Write the commands to demonstrate how session affinity works:**
1. Create a deployment with 3 replicas
2. Create a service with session affinity
3. Test that requests from the same client go to the same Pod

---

**56. Write a multi-port Service manifest for an application that exposes both HTTP (80) and metrics (9090).**

---

---

## Answer Key

### Section 1: Multiple Choice

| Q | Answer | Explanation |
|---|--------|-------------|
| 1 | b | Services provide stable networking and service discovery for dynamic Pods |
| 2 | c | ClusterIP is the default Service type |
| 3 | b | NodePort exposes the service on each node's IP at a static port |
| 4 | c | NodePorts must be in the range 30000-32767 |
| 5 | b | Within the same namespace, just the service name works |
| 6 | b | Format: `<service>.<namespace>.svc.cluster.local` |
| 7 | b | Endpoints object tracks Pod IPs for a Service |
| 8 | b | Setting `clusterIP: None` creates a headless service |
| 9 | b | Selector-less services are used for external resources |
| 10 | c | ExternalName creates a CNAME DNS record |
| 11 | c | Failed readiness removes Pod from Endpoints |
| 12 | b | `kubectl expose deployment` creates a Service |
| 13 | b | ClientIP affinity routes same client to same Pod |
| 14 | b | targetPort is the Pod port receiving traffic |
| 15 | b | Multi-port services require named ports |
| 16 | b | `kubectl get endpoints` shows the Pod IPs |
| 17 | b | DNS works regardless of Service creation order |
| 18 | d | ExternalName creates DNS aliases for external services |
| 19 | b | `-o wide` shows the selector column |
| 20 | b | Applications use the `port` value (8080); Service routes to `targetPort` |

### Section 2: True or False

| Q | Answer | Explanation |
|---|--------|-------------|
| 21 | False | ClusterIP is only accessible from within the cluster |
| 22 | True | NodePort includes a ClusterIP plus a node port |
| 23 | True | Endpoints are automatically maintained by Kubernetes |
| 24 | False | Headless services return all Pod IPs without load balancing |
| 25 | False | Selectors can include multiple labels |
| 26 | False | Environment variables are set at Pod start and not updated |
| 27 | True | Readiness probe failures remove Pods from Endpoints |
| 28 | False | ExternalName only works with DNS names, not IPs |
| 29 | True | NodePort type includes ClusterIP functionality |
| 30 | False | Services only select Pods in the same namespace |

### Section 3: Fill in the Blank

| Q | Answer |
|---|--------|
| 31 | `NodePort` |
| 32 | `None` |
| 33 | `backend` or `backend.svc.cluster.local` |
| 34 | `endpoints` |
| 35 | `selector` |
| 36 | `ClientIP` |
| 37 | `8080` |
| 38 | `None` |
| 39 | A valid DNS name (e.g., `api.external.com`) |
| 40 | `namespace` |

### Section 4: Short Answer

**41.** 
- **ClusterIP**: Internal-only virtual IP accessible within the cluster. Use for internal service-to-service communication.
- **NodePort**: Extends ClusterIP by also exposing the service on each node's IP at a static port (30000-32767). Use when you need external access without a cloud load balancer.

**42.** Endpoints are Kubernetes objects that contain the IP addresses and ports of Pods matching a Service's selector. Kubernetes automatically creates and maintains an Endpoints object for each Service. When Pods are added, removed, or fail readiness checks, the Endpoints are updated accordingly. Services use Endpoints to know where to route traffic.

**43.** Scenario: Connecting to an external database during migration.
1. Create a selector-less Service (no `selector` field)
2. Manually create an Endpoints object with the external database IP
3. Applications connect using the Service DNS name
4. Later, when the database is migrated to Kubernetes, add a selector to the Service and remove the manual Endpoints

**44.** Headless services have `clusterIP: None`. Instead of providing a single virtual IP with load balancing:
- DNS returns all Pod IPs directly (A records)
- No load balancing is performed
- Use cases: StatefulSets (stable network identity), client-side load balancing, peer discovery in distributed systems, service meshes

**45.** DNS-based discovery advantages:
- Services can be created/modified after Pods start
- DNS always returns current information
- Easier to understand and debug
- Works across namespaces with proper naming
- Environment variables are static; set only at Pod startup

**46.** Troubleshooting steps:
1. `kubectl get endpoints <service>` - Check if endpoints exist
2. `kubectl get svc <service> -o yaml` - Verify selector
3. `kubectl get pods --show-labels` - Verify pods have matching labels
4. `kubectl get pods` - Check pods are Running
5. `kubectl describe pod <pod>` - Check readiness probe status
6. `kubectl describe svc <service>` - Check for events/errors

**47.** Relationship:
1. Services select Pods using label selectors
2. Kubernetes watches Pods and maintains Endpoints
3. Readiness probes determine if Pods can receive traffic
4. Pods passing readiness are added to Endpoints
5. Pods failing readiness are removed from Endpoints
6. Only Pods in Endpoints receive traffic from the Service

**48.** ExternalName limitations:
- Only works with DNS names, not IP addresses
- Returns a CNAME, which some applications don't handle well
- No proxying or load balancing
- Client must resolve the returned DNS name
- Doesn't work with IP-based applications
- Can't use with port remapping

### Section 5: Practical Scenarios

**49.**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
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
  name: api
spec:
  selector:
    app: api-server
  ports:
  - port: 8080
    targetPort: 80
```

**50.**
```bash
# 1. Create deployment
kubectl create deployment web --image=nginx:alpine --replicas=2

# 2. Expose as NodePort
kubectl expose deployment web --port=80 --type=NodePort

# Edit to set specific nodePort (or use YAML)
kubectl patch svc web --type='json' -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":30100}]'

# 3. Verify
kubectl get svc web
kubectl get endpoints web

# 4. Test connectivity
kubectl run test --image=busybox:latest --rm -it --restart=Never -- wget -qO- http://web:80
```

**51.**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  ports:
  - port: 3306
    targetPort: 3306
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
subsets:
  - addresses:
      - ip: 10.0.0.50
      - ip: 10.0.0.51
    ports:
      - port: 3306
```

**52.**
```bash
# 1. Create namespaces
kubectl create namespace frontend
kubectl create namespace backend

# 2. Deploy applications
kubectl create deployment webapp --image=nginx:alpine -n frontend
kubectl create deployment api --image=nginx:alpine -n backend

# 3. Create services
kubectl expose deployment webapp --port=80 -n frontend
kubectl expose deployment api --port=80 -n backend

# 4. Test cross-namespace
kubectl run test -n frontend --image=busybox:latest --rm -it --restart=Never -- \
  wget -qO- http://api.backend.svc.cluster.local:80
```

**53.**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: database-headless
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
```

**54.** Migration steps:
1. Create a selector-less Service named `database`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: database
   spec:
     ports:
     - port: 5432
   ```
2. Create Endpoints pointing to external database IP
3. Applications connect via `database:5432` (DNS)
4. Deploy database Pod in Kubernetes with label `app: database`
5. Add `selector: app: database` to the Service
6. Delete manual Endpoints (now auto-managed)
7. Applications continue working without changes

**55.**
```bash
# 1. Create deployment
kubectl create deployment sticky-test --image=nginx:alpine --replicas=3

# 2. Create service with session affinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sticky-svc
spec:
  selector:
    app: sticky-test
  sessionAffinity: ClientIP
  ports:
  - port: 80
EOF

# 3. Test (all requests go to same pod)
kubectl run test --image=busybox:latest --rm -it --restart=Never -- sh -c \
  'for i in 1 2 3 4 5; do wget -qO- http://sticky-svc:80 | head -1; done'
```

**56.**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-app
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: metrics
    port: 9090
    targetPort: 9090
```

---

## Scoring Guide

| Score | Level |
|-------|-------|
| 50-56 | Expert – Ready for advanced Kubernetes networking |
| 42-49 | Proficient – Solid understanding, minor gaps |
| 34-41 | Intermediate – Review networking concepts |
| 25-33 | Beginner – Review core Service concepts |
| 0-24 | Needs Review – Retake the lab exercises |


