# Kubernetes ReplicaSets and Deployments – Test Questions

Use these questions to assess participant understanding after completing the ReplicaSets and Deployments lab.

---

## Section 1: Multiple Choice

**1. What is the primary purpose of a ReplicaSet?**

a) To store application configuration  
b) To ensure a specified number of Pod replicas are running  
c) To route network traffic to Pods  
d) To manage container images  

---

**2. What is a reconciliation loop in Kubernetes?**

a) A loop that checks user permissions  
b) A continuous process that compares desired state to current state and takes action  
c) A mechanism for authenticating API requests  
d) A way to encrypt Pod data  

---

**3. Which field in a ReplicaSet spec defines how to identify Pods it should manage?**

a) `replicas`  
b) `template`  
c) `selector`  
d) `metadata`  

---

**4. What happens when you delete a Pod managed by a ReplicaSet?**

a) The ReplicaSet is also deleted  
b) The Pod is marked as unhealthy  
c) The ReplicaSet creates a new Pod to replace it  
d) Nothing, the Pod stays deleted  

---

**5. What is the relationship between a Deployment and a ReplicaSet?**

a) They are the same object  
b) A Deployment creates and manages ReplicaSets  
c) A ReplicaSet creates and manages Deployments  
d) They are independent and unrelated  

---

**6. What is the default rollout strategy for Deployments?**

a) Recreate  
b) BlueGreen  
c) RollingUpdate  
d) Canary  

---

**7. What does the Recreate strategy do during a Deployment update?**

a) Updates one Pod at a time  
b) Terminates all old Pods before creating new ones  
c) Maintains full capacity throughout the update  
d) Creates new Pods while keeping old ones running  

---

**8. What does `maxSurge: 25%` mean in a RollingUpdate strategy?**

a) 25% of Pods can be unavailable during update  
b) Up to 25% extra Pods can be created during update  
c) The update happens 25% faster  
d) 25% of Pods are updated simultaneously  

---

**9. What does `maxUnavailable: 0` ensure during a RollingUpdate?**

a) No downtime - all Pods remain available  
b) The update happens instantly  
c) Pods are not health-checked  
d) The update is paused indefinitely  

---

**10. Which command shows the rollout history of a Deployment?**

a) `kubectl get deployment --history`  
b) `kubectl rollout history deployment <name>`  
c) `kubectl describe deployment <name> --revisions`  
d) `kubectl logs deployment <name>`  

---

**11. What command rolls back a Deployment to the previous version?**

a) `kubectl rollout previous deployment <name>`  
b) `kubectl rollout undo deployment <name>`  
c) `kubectl revert deployment <name>`  
d) `kubectl deployment rollback <name>`  

---

**12. What does `minReadySeconds` configure in a Deployment?**

a) Minimum time a Pod must be ready before it's considered available  
b) Minimum number of ready Pods  
c) Time before the first readiness check  
d) Minimum CPU seconds per Pod  

---

**13. What happens when `progressDeadlineSeconds` is exceeded during a rollout?**

a) The rollout is automatically rolled back  
b) The Deployment is deleted  
c) The rollout is marked as failed  
d) Kubernetes restarts all Pods  

---

**14. What is Horizontal Pod Autoscaling (HPA)?**

a) Adding more CPU to existing Pods  
b) Automatically adjusting the number of Pod replicas based on metrics  
c) Spreading Pods across multiple nodes  
d) Increasing Pod memory limits  

---

**15. What must be defined on Pods for CPU-based HPA to work?**

a) Labels  
b) Annotations  
c) Resource requests  
d) Environment variables  

---

**16. What is the purpose of `revisionHistoryLimit` in a Deployment?**

a) Limits the number of Pods per revision  
b) Limits how many old ReplicaSets are kept for rollback  
c) Limits the rollout speed  
d) Limits the number of containers per Pod  

---

**17. What happens when you "quarantine" a Pod from a ReplicaSet?**

a) The Pod is deleted  
b) The Pod's labels are changed so it's no longer selected by the ReplicaSet  
c) The Pod is restarted  
d) The ReplicaSet is paused  

---

**18. Which command pauses an ongoing rollout?**

a) `kubectl rollout stop deployment <name>`  
b) `kubectl rollout pause deployment <name>`  
c) `kubectl rollout wait deployment <name>`  
d) `kubectl pause deployment <name>`  

---

**19. What does `kubectl set image deployment/myapp app=nginx:1.25` do?**

a) Creates a new deployment  
b) Updates the container image and triggers a rollout  
c) Rolls back to the previous image  
d) Only updates the YAML file  

---

**20. What's the main advantage of using Deployments over ReplicaSets directly?**

a) Deployments are faster  
b) Deployments provide version management and rollback capabilities  
c) Deployments use less memory  
d) Deployments don't require selectors  

---

## Section 2: True or False

**21. ReplicaSets can adopt existing Pods that match their label selector.**

☐ True  
☐ False  

---

**22. Scaling a ReplicaSet directly when it's managed by a Deployment will permanently change the replica count.**

☐ True  
☐ False  

---

**23. The Recreate strategy results in downtime during Deployment updates.**

☐ True  
☐ False  

---

**24. During a RollingUpdate, both old and new versions of the application serve traffic simultaneously.**

☐ True  
☐ False  

---

**25. Rollback is only possible if the Deployment update completed successfully.**

☐ True  
☐ False  

---

**26. HPA requires metrics-server to be installed in the cluster.**

☐ True  
☐ False  

---

**27. The selector labels in a ReplicaSet must exactly match all labels in the Pod template.**

☐ True  
☐ False  

---

**28. Setting maxSurge to 100% and maxUnavailable to 0 implements a blue/green deployment pattern.**

☐ True  
☐ False  

---

**29. Deleting a Deployment automatically deletes its managed ReplicaSets and Pods.**

☐ True  
☐ False  

---

**30. A Pod can only be managed by one ReplicaSet at a time.**

☐ True  
☐ False  

---

## Section 3: Fill in the Blank

**31. Complete the command to scale a deployment named `webapp` to 5 replicas:**

```bash
kubectl __________ deployment webapp --replicas=5
```

---

**32. Complete the Deployment spec to use the Recreate strategy:**

```yaml
spec:
  strategy:
    type: __________
```

---

**33. Complete the command to roll back a deployment to revision 3:**

```bash
kubectl rollout undo deployment myapp --to-revision=__________
```

---

**34. In a RollingUpdate, the __________ parameter controls how many extra Pods can be created.**

---

**35. Complete the command to view the rollout status of a deployment:**

```bash
kubectl rollout __________ deployment myapp
```

---

**36. Complete the command to create an HPA with min 2, max 10 replicas, and 80% CPU target:**

```bash
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=__________
```

---

**37. The __________ field in a ReplicaSet defines the specification for creating new Pods.**

---

**38. Complete the command to view details of a specific rollout revision:**

```bash
kubectl rollout history deployment myapp __________=2
```

---

**39. To prevent a Deployment from making progress beyond a certain time, set the __________ field.**

---

**40. A ReplicaSet uses the __________ loop to ensure the desired number of Pods are running.**

---

## Section 4: Short Answer

**41. Explain the difference between a ReplicaSet and a Deployment. When would you use each?**

---

**42. What is "Pod adoption" in the context of ReplicaSets, and why is it useful?**

---

**43. Describe the reconciliation loop and its role in ReplicaSets.**

---

**44. Compare and contrast the Recreate and RollingUpdate deployment strategies. When would you use each?**

---

**45. Explain how maxSurge and maxUnavailable work together to control rollout behavior.**

---

**46. What is the purpose of minReadySeconds and how does it improve rollout safety?**

---

**47. Describe the "quarantine" technique for debugging a misbehaving Pod in a ReplicaSet.**

---

**48. How does Kubernetes maintain backward compatibility during rolling updates, and why is it important?**

---

## Section 5: Practical Scenarios

**49. Write a complete YAML manifest for a Deployment with:**
- Name: `api-server`
- 4 replicas
- RollingUpdate strategy with maxSurge: 1, maxUnavailable: 0
- Container image: `myapi:v1`
- Readiness probe on port 8080

---

**50. Write the commands to:**
1. Create a deployment named `web` with 3 replicas using nginx:1.24
2. Update the image to nginx:1.25
3. View the rollout history
4. Roll back to the previous version
5. Verify the current image

---

**51. Write a ReplicaSet manifest that:**
- Has 5 replicas
- Uses selector `app: cache, tier: backend`
- Creates pods with image redis:alpine

---

**52. You have a Deployment with 10 replicas. Write the rolling update configuration to:**
- Never have more than 12 pods running
- Never have fewer than 8 pods available

---

**53. Write the commands to implement a blue/green deployment:**
1. Create "blue" deployment with label version=blue
2. Create a service selecting the blue deployment
3. Create "green" deployment with label version=green
4. Switch the service to the green deployment
5. Delete the blue deployment

---

**54. A team reports their deployment rollout is stuck. Write the commands to:**
1. Check the rollout status
2. View the deployment events
3. Check pod status
4. Roll back if necessary

---

**55. Write the commands to set up Horizontal Pod Autoscaling for a deployment that:**
- Scales between 3 and 20 replicas
- Targets 70% CPU utilization
- Verify the HPA is working

---

**56. Write a Deployment manifest with:**
- minReadySeconds: 30
- progressDeadlineSeconds: 300
- revisionHistoryLimit: 5
- Change-cause annotation

---

---

## Answer Key

### Section 1: Multiple Choice

| Q | Answer | Explanation |
|---|--------|-------------|
| 1 | b | ReplicaSets ensure a specified number of Pod replicas are running |
| 2 | b | Reconciliation loops continuously compare and reconcile desired vs current state |
| 3 | c | The selector field defines which Pods the ReplicaSet manages |
| 4 | c | ReplicaSet's reconciliation loop creates a replacement Pod |
| 5 | b | Deployments create and manage ReplicaSets |
| 6 | c | RollingUpdate is the default strategy |
| 7 | b | Recreate terminates all old Pods before creating new ones |
| 8 | b | maxSurge allows creating extra Pods during update |
| 9 | a | maxUnavailable: 0 ensures all Pods remain available |
| 10 | b | `kubectl rollout history deployment <name>` shows history |
| 11 | b | `kubectl rollout undo` rolls back a Deployment |
| 12 | a | Time a Pod must be ready before considered available |
| 13 | c | The rollout is marked as failed (not auto-rolled back) |
| 14 | b | HPA adjusts replica count based on metrics |
| 15 | c | Resource requests are required for CPU-based HPA |
| 16 | b | Limits old ReplicaSets kept for rollback |
| 17 | b | Labels are changed to remove the Pod from selection |
| 18 | b | `kubectl rollout pause` pauses a rollout |
| 19 | b | Updates image and triggers rollout |
| 20 | b | Deployments provide version management and rollback |

### Section 2: True or False

| Q | Answer | Explanation |
|---|--------|-------------|
| 21 | True | ReplicaSets adopt Pods matching their selector |
| 22 | False | The Deployment overrides changes to its managed ReplicaSet |
| 23 | True | Recreate has downtime between old Pod termination and new Pod creation |
| 24 | True | Both versions run simultaneously during RollingUpdate |
| 25 | False | Rollback works for both complete and in-progress rollouts |
| 26 | True | HPA uses metrics from metrics-server |
| 27 | False | Selector must be a subset of template labels, not exact match |
| 28 | True | This creates new version fully before removing old (blue/green) |
| 29 | True | Deleting Deployment cascades to ReplicaSets and Pods |
| 30 | True | A Pod can only have one owner reference at a time |

### Section 3: Fill in the Blank

| Q | Answer |
|---|--------|
| 31 | `scale` |
| 32 | `Recreate` |
| 33 | `3` |
| 34 | `maxSurge` |
| 35 | `status` |
| 36 | `80` |
| 37 | `template` |
| 38 | `--revision` |
| 39 | `progressDeadlineSeconds` |
| 40 | `reconciliation` |

### Section 4: Short Answer

**41.** 
- **ReplicaSet**: Ensures a specified number of Pods are running. Manages Pods directly using label selectors. No built-in version management or rollback.
- **Deployment**: Manages ReplicaSets, providing version control, rollout strategies, rollback capabilities, and history tracking.

Use Deployments for applications that need updates and version management (most use cases). Use ReplicaSets directly only if you need custom update logic or are learning the fundamentals.

**42.** Pod adoption occurs when a ReplicaSet finds existing Pods matching its selector and takes ownership of them instead of creating new ones. This is useful for:
- Migrating from standalone Pods to managed Pods without downtime
- Recovering orphaned Pods when a ReplicaSet is recreated
- Seamlessly transitioning from imperative to declarative management

**43.** The reconciliation loop is a continuous control loop that:
1. **Observes** the current state (counts Pods matching the selector)
2. **Compares** to desired state (spec.replicas)
3. **Acts** to reconcile differences (creates or deletes Pods)

This self-healing approach is fundamental to Kubernetes - it ensures the system continuously converges toward the desired state, handling failures, scaling events, and manual interventions automatically.

**44.** 
- **Recreate**: Terminates all old Pods before creating new ones
  - Pros: Simple, no version compatibility concerns
  - Cons: Causes downtime
  - Use for: Test environments, stateful apps that can't run multiple versions

- **RollingUpdate**: Gradually replaces old Pods with new ones
  - Pros: Zero downtime, can pause/resume
  - Cons: Both versions run simultaneously (requires compatibility)
  - Use for: Production services, user-facing applications

**45.** 
- **maxSurge**: Maximum extra Pods beyond desired count during update
- **maxUnavailable**: Maximum Pods that can be unavailable during update

Together they control the pace and safety of rollouts:
- High maxSurge + low maxUnavailable = Fast, resource-intensive, always at capacity
- Low maxSurge + high maxUnavailable = Faster but reduced capacity
- maxSurge=0, maxUnavailable=1 = Very slow but minimal extra resources
- maxSurge=100%, maxUnavailable=0 = Blue/green deployment

**46.** `minReadySeconds` specifies the minimum time a Pod must be "Ready" before being considered "Available" and continuing the rollout. This improves safety by:
- Allowing time for latent issues to surface
- Preventing cascading failures from bad updates
- Ensuring stability before reducing old version capacity
- Catching issues that don't appear immediately (memory leaks, race conditions)

**47.** Quarantining steps:
1. Identify the misbehaving Pod
2. Remove or change its labels so it no longer matches the ReplicaSet selector
3. The ReplicaSet creates a replacement Pod (maintaining desired count)
4. The quarantined Pod continues running for debugging
5. You can exec into it, check logs, run diagnostics
6. Delete the quarantined Pod when done

This preserves the running state for investigation while maintaining service availability.

**48.** During rolling updates, both old and new versions serve traffic simultaneously. Backward compatibility requires:
- API versioning (new servers handle old API calls)
- Data format compatibility (new code reads old data)
- Client compatibility (old clients work with new servers)

This is important because:
- Updates are never instant
- Users may have cached old client code
- Dependent services may not update simultaneously
- Enables safe rollback if issues are discovered

### Section 5: Practical Scenarios

**49.**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
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
        image: myapi:v1
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

**50.**
```bash
# 1. Create deployment
kubectl create deployment web --image=nginx:1.24 --replicas=3

# 2. Update image
kubectl set image deployment/web nginx=nginx:1.25 --record

# 3. View history
kubectl rollout history deployment web

# 4. Roll back
kubectl rollout undo deployment web

# 5. Verify image
kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**51.**
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: cache-rs
spec:
  replicas: 5
  selector:
    matchLabels:
      app: cache
      tier: backend
  template:
    metadata:
      labels:
        app: cache
        tier: backend
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
```

**52.**
```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # 10 + 2 = 12 max
      maxUnavailable: 2   # 10 - 2 = 8 min available
```
Or using percentages:
```yaml
      maxSurge: 20%
      maxUnavailable: 20%
```

**53.**
```bash
# 1. Create blue deployment
kubectl create deployment app-blue --image=myapp:v1 --replicas=3
kubectl label deployment app-blue version=blue

# 2. Create service
kubectl expose deployment app-blue --port=80 --name=myapp-svc
# Or manually patch selector:
kubectl patch svc myapp-svc -p '{"spec":{"selector":{"app":"app-blue"}}}'

# 3. Create green deployment
kubectl create deployment app-green --image=myapp:v2 --replicas=3
kubectl label deployment app-green version=green

# Wait for green to be ready
kubectl rollout status deployment app-green

# 4. Switch service to green
kubectl patch svc myapp-svc -p '{"spec":{"selector":{"app":"app-green"}}}'

# 5. Delete blue
kubectl delete deployment app-blue
```

**54.**
```bash
# 1. Check rollout status
kubectl rollout status deployment myapp

# 2. View events
kubectl describe deployment myapp

# 3. Check pods
kubectl get pods -l app=myapp
kubectl describe pods -l app=myapp | grep -A 10 Events

# Check for failing pods
kubectl get pods -l app=myapp | grep -v Running

# Check pod logs if needed
kubectl logs -l app=myapp --tail=50

# 4. Roll back if necessary
kubectl rollout undo deployment myapp
kubectl rollout status deployment myapp
```

**55.**
```bash
# Ensure deployment has resource requests
kubectl patch deployment myapp --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"cpu": "100m", "memory": "128Mi"}}}]'

# Create HPA
kubectl autoscale deployment myapp --min=3 --max=20 --cpu-percent=70

# Verify HPA
kubectl get hpa myapp
kubectl describe hpa myapp

# Watch HPA
kubectl get hpa myapp --watch
```

**56.**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-app
  annotations:
    kubernetes.io/change-cause: "Initial deployment v1.0"
spec:
  replicas: 3
  minReadySeconds: 30
  progressDeadlineSeconds: 300
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: stable-app
  template:
    metadata:
      labels:
        app: stable-app
      annotations:
        kubernetes.io/change-cause: "Initial deployment v1.0"
    spec:
      containers:
      - name: app
        image: myapp:v1
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

---

## Scoring Guide

| Score | Level |
|-------|-------|
| 50-56 | Expert – Ready for advanced Kubernetes workload management |
| 42-49 | Proficient – Solid understanding, minor gaps |
| 34-41 | Intermediate – Review deployment strategies |
| 25-33 | Beginner – Review core ReplicaSet and Deployment concepts |
| 0-24 | Needs Review – Retake the lab exercises |


