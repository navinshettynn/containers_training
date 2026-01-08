# Kubernetes Secrets and ConfigMaps – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services)

> **Important**: This lab assumes familiarity with kubectl commands, Pod concepts (labels, volumes, environment variables), and basic YAML syntax. If you haven't completed the previous labs, do those first.

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

### ConfigMaps

- Understand what a **ConfigMap** is and when to use it
- Create ConfigMaps using **imperative commands** and **declarative YAML**
- Use ConfigMaps as **environment variables**
- Use ConfigMaps as **mounted volumes**
- Update ConfigMaps and understand **propagation behavior**

### Secrets

- Understand what a **Secret** is and how it differs from ConfigMaps
- Learn about **Secret types** (Opaque, docker-registry, TLS, etc.)
- Create Secrets using **imperative commands** and **declarative YAML**
- Use Secrets as **environment variables** and **mounted volumes**
- Understand **base64 encoding** and Secret security considerations

### Intermediate Objectives (Optional)

- Configure **immutable** ConfigMaps and Secrets
- Use **stringData** for easier Secret creation
- Implement **subPath** for selective file mounting
- Configure **optional** ConfigMaps and Secrets

---

## Part 1: Understanding ConfigMaps

### What is a ConfigMap?

A ConfigMap is a Kubernetes object used to store **non-confidential configuration data** in key-value pairs.

| Feature | Description |
|---------|-------------|
| **Key-value storage** | Store configuration as simple key-value pairs |
| **File storage** | Store entire configuration files |
| **Decoupled config** | Separate configuration from container images |
| **Dynamic updates** | Update configuration without rebuilding images |

### When to Use ConfigMaps

| Use Case | Example |
|----------|---------|
| Application settings | Database hostnames, feature flags |
| Configuration files | nginx.conf, app.properties |
| Environment-specific values | Dev/Staging/Prod URLs |
| Command-line arguments | Startup parameters |

### ConfigMap vs Hardcoded Config

| Approach | Pros | Cons |
|----------|------|------|
| Hardcoded in image | Simple, no external dependencies | Requires rebuild for changes |
| Environment variables in Pod spec | Quick, visible in manifest | Config scattered across manifests |
| **ConfigMap** | Centralized, reusable, easy updates | Additional object to manage |

---

## Part 2: Creating ConfigMaps

### Create a Lab Directory

```bash
mkdir -p ~/secrets-configmaps-lab
cd ~/secrets-configmaps-lab
```

### Create ConfigMap from Literal Values (Imperative)

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=development \
  --from-literal=APP_DEBUG=true \
  --from-literal=LOG_LEVEL=info

# View the ConfigMap
kubectl get configmap app-config
kubectl describe configmap app-config
```

### View ConfigMap Data

```bash
kubectl get configmap app-config -o yaml
```

Output shows:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_DEBUG: "true"
  APP_ENV: development
  LOG_LEVEL: info
```

### Create ConfigMap from File (Imperative)

```bash
# Create a configuration file
cat > app.properties <<'EOF'
database.host=localhost
database.port=5432
database.name=myapp
cache.enabled=true
cache.ttl=3600
EOF

# Create ConfigMap from file
kubectl create configmap app-properties --from-file=app.properties

# View the ConfigMap
kubectl describe configmap app-properties
```

### Create ConfigMap from Directory

```bash
# Create multiple config files
mkdir -p config-files
echo "server.port=8080" > config-files/server.conf
echo "logging.level=DEBUG" > config-files/logging.conf

# Create ConfigMap from directory
kubectl create configmap multi-file-config --from-file=config-files/

# View the ConfigMap
kubectl get configmap multi-file-config -o yaml
```

### Create ConfigMap Declaratively (YAML)

```bash
cat > configmap-declarative.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  labels:
    app: webapp
data:
  # Simple key-value pairs
  APP_NAME: "My Web Application"
  APP_VERSION: "1.0.0"
  FEATURE_FLAG_NEW_UI: "true"
  
  # Multi-line configuration file
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
  
  # JSON configuration
  app-settings.json: |
    {
      "database": {
        "host": "db.example.com",
        "port": 5432
      },
      "cache": {
        "enabled": true,
        "ttl": 300
      }
    }
EOF

kubectl apply -f configmap-declarative.yaml
kubectl describe configmap webapp-config
```

### Cleanup Part 2

```bash
kubectl delete configmap app-config app-properties multi-file-config webapp-config
rm -rf config-files app.properties
```

---

## Part 3: Using ConfigMaps in Pods

### Using ConfigMap as Environment Variables

#### Single Environment Variable

```bash
cat > configmap-env-single.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:
  DB_HOST: "mysql.database.svc.cluster.local"
  DB_PORT: "3306"
  DB_NAME: "myapp"
---
apiVersion: v1
kind: Pod
metadata:
  name: env-single-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "echo DB_HOST=$DB_HOST && sleep 3600"]
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: db-config
          key: DB_HOST
  restartPolicy: Never
EOF

kubectl apply -f configmap-env-single.yaml
sleep 5
kubectl logs env-single-demo
```

#### All Keys as Environment Variables

```bash
cat > configmap-env-all.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  APP_ENV: "production"
  APP_DEBUG: "false"
  LOG_LEVEL: "warn"
  MAX_CONNECTIONS: "100"
---
apiVersion: v1
kind: Pod
metadata:
  name: env-all-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "env | grep -E 'APP_|LOG_|MAX_' && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-settings
  restartPolicy: Never
EOF

kubectl apply -f configmap-env-all.yaml
sleep 5
kubectl logs env-all-demo
```

### Using ConfigMap as Volume Mount

#### Mount Entire ConfigMap

```bash
cat > configmap-volume.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        server {
            listen 80;
            location / {
                return 200 'Hello from ConfigMap!\n';
                add_header Content-Type text/plain;
            }
        }
    }
  custom.conf: |
    # Additional custom configuration
    client_max_body_size 10M;
---
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
EOF

kubectl apply -f configmap-volume.yaml
kubectl wait --for=condition=Ready pod/volume-demo --timeout=60s
```

### Test the Configuration

```bash
# Port forward to test
kubectl port-forward volume-demo 8080:80 &
sleep 2

# Test the endpoint
curl localhost:8080

# Stop port forwarding
pkill -f "port-forward volume-demo"
```

### View Mounted Files

```bash
kubectl exec volume-demo -- cat /etc/nginx/nginx.conf
```

### Mount Specific Keys

```bash
cat > configmap-selective-mount.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-config
data:
  config.yaml: |
    app:
      name: myapp
      version: "1.0"
  secrets.yaml: |
    # This is not a real secret, just a demo
    api_key: demo-key
  logging.yaml: |
    level: debug
    format: json
---
apiVersion: v1
kind: Pod
metadata:
  name: selective-mount-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "ls -la /config && cat /config/* && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: multi-config
      items:
      - key: config.yaml
        path: app-config.yaml
      - key: logging.yaml
        path: log-config.yaml
      # Note: secrets.yaml is not mounted
EOF

kubectl apply -f configmap-selective-mount.yaml
sleep 5
kubectl logs selective-mount-demo
```

### Cleanup Part 3

```bash
kubectl delete pod env-single-demo env-all-demo volume-demo selective-mount-demo
kubectl delete configmap db-config app-settings nginx-config multi-config
```

---

## Part 4: Understanding Secrets

### What is a Secret?

A Secret is a Kubernetes object used to store **sensitive data** such as passwords, tokens, and keys.

| Feature | Description |
|---------|-------------|
| **Base64 encoded** | Data is encoded (not encrypted by default) |
| **Type-specific** | Different types for different use cases |
| **Access control** | Can be restricted via RBAC |
| **Memory storage** | Stored in tmpfs when mounted (not written to disk) |

### Secret vs ConfigMap

| Aspect | Secret | ConfigMap |
|--------|--------|-----------|
| **Purpose** | Sensitive data | Non-sensitive configuration |
| **Encoding** | Base64 encoded | Plain text |
| **Size limit** | 1 MB | 1 MB |
| **Mounted storage** | tmpfs (RAM) | Regular filesystem |
| **API access** | Can be restricted | Generally accessible |

### Secret Types

| Type | Description | Use Case |
|------|-------------|----------|
| `Opaque` | Generic, user-defined data | Passwords, API keys |
| `kubernetes.io/dockerconfigjson` | Docker registry credentials | Image pulling |
| `kubernetes.io/tls` | TLS certificate and key | HTTPS termination |
| `kubernetes.io/basic-auth` | Basic authentication | Username/password |
| `kubernetes.io/ssh-auth` | SSH private key | Git operations |
| `kubernetes.io/service-account-token` | Service account token | API authentication |

> **Security Note**: Base64 encoding is NOT encryption. Anyone with API access can decode secrets. For production, consider:
> - RBAC to restrict access
> - Encryption at rest (etcd encryption)
> - External secret management (Vault, AWS Secrets Manager)

---

## Part 5: Creating Secrets

### Create Secret from Literal Values (Imperative)

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='S3cur3P@ssw0rd!'

# View the Secret
kubectl get secret db-credentials
kubectl describe secret db-credentials
```

Note: `describe` doesn't show the actual values.

### View Secret Data (Base64 Encoded)

```bash
kubectl get secret db-credentials -o yaml
```

Output shows base64-encoded values:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  password: UzNjdXIzUEBzc3cwcmQh
  username: YWRtaW4=
```

### Decode Secret Values

```bash
# Decode using base64
kubectl get secret db-credentials -o jsonpath='{.data.username}' | base64 --decode
echo  # Add newline
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 --decode
echo
```

### Create Secret from File (Imperative)

```bash
# Create files with sensitive data
echo -n "admin" > username.txt
echo -n "S3cur3P@ssw0rd!" > password.txt

# Create Secret from files
kubectl create secret generic file-credentials \
  --from-file=username=username.txt \
  --from-file=password=password.txt

# Cleanup sensitive files
rm username.txt password.txt

# Verify
kubectl describe secret file-credentials
```

### Create Secret Declaratively (YAML) - Base64 Encoded

```bash
# First, encode values
echo -n "myuser" | base64
echo -n "mypassword123" | base64
```

```bash
cat > secret-base64.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: encoded-secret
type: Opaque
data:
  username: bXl1c2Vy          # base64 encoded "myuser"
  password: bXlwYXNzd29yZDEyMw==  # base64 encoded "mypassword123"
EOF

kubectl apply -f secret-base64.yaml
```

### Create Secret Declaratively (YAML) - Using stringData

```bash
cat > secret-stringdata.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: plaintext-secret
type: Opaque
stringData:
  # No base64 encoding needed!
  username: myuser
  password: mypassword123
  config.yaml: |
    database:
      host: db.example.com
      port: 5432
EOF

kubectl apply -f secret-stringdata.yaml
kubectl get secret plaintext-secret -o yaml
```

> **Note**: `stringData` is converted to base64-encoded `data` when the Secret is created. It's a convenience for creating Secrets without manual encoding.

### Create Docker Registry Secret

```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myuser@example.com

kubectl get secret my-registry-secret -o yaml
```

### Create TLS Secret

```bash
# Generate self-signed certificate (for demo only)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com/O=Demo"

# Create TLS secret
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key

# View the secret
kubectl describe secret my-tls-secret

# Cleanup certificate files
rm tls.key tls.crt
```

### Cleanup Part 5

```bash
kubectl delete secret db-credentials file-credentials encoded-secret plaintext-secret my-registry-secret my-tls-secret
rm -f secret-base64.yaml secret-stringdata.yaml
```

---

## Part 6: Using Secrets in Pods

### Using Secret as Environment Variables

#### Single Environment Variable

```bash
cat > secret-env-single.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: api-secret
type: Opaque
stringData:
  api-key: "sk-1234567890abcdef"
  api-url: "https://api.example.com"
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-single
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "echo API_KEY=$API_KEY && echo API_URL=$API_URL && sleep 3600"]
    env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: api-secret
          key: api-key
    - name: API_URL
      valueFrom:
        secretKeyRef:
          name: api-secret
          key: api-url
  restartPolicy: Never
EOF

kubectl apply -f secret-env-single.yaml
sleep 5
kubectl logs secret-env-single
```

#### All Keys as Environment Variables

```bash
cat > secret-env-all.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  DB_HOST: "mysql.database.svc"
  DB_PORT: "3306"
  DB_USER: "appuser"
  DB_PASSWORD: "SecretPass123!"
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-all
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "env | grep DB_ && sleep 3600"]
    envFrom:
    - secretRef:
        name: db-secret
  restartPolicy: Never
EOF

kubectl apply -f secret-env-all.yaml
sleep 5
kubectl logs secret-env-all
```

### Using Secret as Volume Mount

```bash
cat > secret-volume.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: ssh-secret
type: Opaque
stringData:
  id_rsa: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    (this is a demo, not a real key)
    -----END OPENSSH PRIVATE KEY-----
  id_rsa.pub: |
    ssh-rsa AAAAB... demo@example.com
  known_hosts: |
    github.com ssh-rsa AAAAB3NzaC1yc2E...
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "ls -la /secrets && cat /secrets/id_rsa.pub && sleep 3600"]
    volumeMounts:
    - name: ssh-volume
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: ssh-volume
    secret:
      secretName: ssh-secret
      defaultMode: 0400  # Read-only for owner
EOF

kubectl apply -f secret-volume.yaml
sleep 5
kubectl logs secret-volume-demo
```

### Verify Secret File Permissions

```bash
kubectl exec secret-volume-demo -- ls -la /secrets
```

### Mount Specific Secret Keys

```bash
cat > secret-selective-mount.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  database-password: "DbPass123"
  api-key: "ApiKey456"
  encryption-key: "EncKey789"
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-selective
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "ls /secrets && cat /secrets/* && sleep 3600"]
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
  volumes:
  - name: secret-volume
    secret:
      secretName: app-secrets
      items:
      - key: database-password
        path: db-pass
      - key: api-key
        path: api-key
      # encryption-key is NOT mounted
EOF

kubectl apply -f secret-selective-mount.yaml
sleep 5
kubectl logs secret-selective
```

### Cleanup Part 6

```bash
kubectl delete pod secret-env-single secret-env-all secret-volume-demo secret-selective
kubectl delete secret api-secret db-secret ssh-secret app-secrets
```

---

## Part 7: Updating ConfigMaps and Secrets

### ConfigMap Update Propagation

```bash
# Create ConfigMap and Pod
cat > update-demo.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: update-config
data:
  message: "Hello, Version 1!"
  config.txt: |
    setting1=value1
    setting2=value2
---
apiVersion: v1
kind: Pod
metadata:
  name: update-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "while true; do echo '--- ENV ---'; echo $MESSAGE; echo '--- FILE ---'; cat /config/config.txt; sleep 10; done"]
    env:
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: update-config
          key: message
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: update-config
EOF

kubectl apply -f update-demo.yaml
sleep 10
kubectl logs update-demo --tail=10
```

### Update the ConfigMap

```bash
kubectl patch configmap update-config --type merge -p '{"data":{"message":"Hello, Version 2!","config.txt":"setting1=updated1\nsetting2=updated2\n"}}'
```

### Observe the Changes

```bash
# Wait for propagation (can take up to 1 minute)
sleep 60
kubectl logs update-demo --tail=20
```

> **Important Observations**:
> - **Volume-mounted files** are updated automatically (with some delay)
> - **Environment variables** are NOT updated (Pod restart required)

### Force Pod Restart for Env Var Updates

```bash
# One way: Delete and recreate
kubectl delete pod update-demo
kubectl apply -f update-demo.yaml

# Or use rollout restart with Deployments
# kubectl rollout restart deployment <name>
```

### Cleanup Part 7

```bash
kubectl delete pod update-demo
kubectl delete configmap update-config
```

---

## Part 8: Immutable ConfigMaps and Secrets

Immutable ConfigMaps and Secrets cannot be modified after creation, providing:
- Protection against accidental updates
- Better cluster performance (no watches needed)

### Create Immutable ConfigMap

```bash
cat > immutable-configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
data:
  APP_VERSION: "1.0.0"
  RELEASE_DATE: "2024-01-15"
immutable: true
EOF

kubectl apply -f immutable-configmap.yaml
```

### Try to Update (Will Fail)

```bash
kubectl patch configmap immutable-config --type merge -p '{"data":{"APP_VERSION":"2.0.0"}}'
```

You'll see an error: `ConfigMap is immutable`.

### Create Immutable Secret

```bash
cat > immutable-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
type: Opaque
stringData:
  api-key: "permanent-key-12345"
immutable: true
EOF

kubectl apply -f immutable-secret.yaml
```

### Managing Immutable Objects

To update immutable ConfigMaps/Secrets:
1. Create a new ConfigMap/Secret with a different name
2. Update Pods to reference the new name
3. Delete the old ConfigMap/Secret

### Cleanup Part 8

```bash
kubectl delete configmap immutable-config
kubectl delete secret immutable-secret
```

---

## Part 9: Advanced Patterns

### Optional ConfigMaps and Secrets

Make ConfigMap/Secret references optional so Pods can start even if they don't exist:

```bash
cat > optional-config.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: optional-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "echo OPT_VALUE=$OPT_VALUE && sleep 3600"]
    env:
    - name: OPT_VALUE
      valueFrom:
        configMapKeyRef:
          name: might-not-exist
          key: some-key
          optional: true
  restartPolicy: Never
EOF

kubectl apply -f optional-config.yaml
sleep 5
kubectl logs optional-demo
```

The Pod starts successfully even though the ConfigMap doesn't exist.

### Combining ConfigMaps and Secrets

```bash
cat > combined-demo.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  DATABASE_HOST: "db.example.com"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  DATABASE_PASSWORD: "SecretPass123"
  API_KEY: "sk-secret-key-12345"
---
apiVersion: v1
kind: Pod
metadata:
  name: combined-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "env | sort | grep -E 'APP_|LOG_|DATABASE_|API_' && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: app-secret
  restartPolicy: Never
EOF

kubectl apply -f combined-demo.yaml
sleep 5
kubectl logs combined-demo
```

### Using subPath for Single File Mount

Mount a single file without replacing the entire directory:

```bash
cat > subpath-demo.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-custom
data:
  custom.conf: |
    # Custom location block
    location /custom {
        return 200 'Custom endpoint';
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: subpath-demo
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    # Mount single file without replacing /etc/nginx/conf.d/
    - name: config
      mountPath: /etc/nginx/conf.d/custom.conf
      subPath: custom.conf
  volumes:
  - name: config
    configMap:
      name: nginx-custom
EOF

kubectl apply -f subpath-demo.yaml
kubectl wait --for=condition=Ready pod/subpath-demo --timeout=60s

# Verify other files in conf.d still exist
kubectl exec subpath-demo -- ls -la /etc/nginx/conf.d/
```

### Cleanup Part 9

```bash
kubectl delete pod optional-demo combined-demo subpath-demo
kubectl delete configmap app-config nginx-custom
kubectl delete secret app-secret
```

---

## Scenario-Based Exercises: Deploying "ShopFast" E-Commerce Platform

You've just joined **TechRetail Inc.** as a DevOps engineer. The company is migrating their e-commerce platform "ShopFast" to Kubernetes. Your task is to properly configure the application using ConfigMaps and Secrets following security best practices.

> **Story Context**: ShopFast consists of a web frontend, an API backend, and connects to a PostgreSQL database. The previous team hardcoded all configurations in Docker images, causing security issues and deployment headaches. Your job is to fix this!

```bash
# Setup: Create your workspace
cd ~/secrets-configmaps-lab
```

---

### Exercise 1: The Hardcoded Disaster (Understanding the Problem)

**Scenario**: Your first day on the job, and there's already a production incident! The previous developer accidentally pushed the Docker image with development database credentials to production. Customers are seeing test data!

**Your Task**: First, let's see what the problematic "hardcoded" approach looks like, then fix it.

#### Step 1: Deploy the "Bad" Version (Hardcoded Config)

```bash
cat > shopfast-bad.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shopfast-bad
  labels:
    app: shopfast
    version: bad
spec:
  containers:
  - name: api
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "=== ShopFast API Starting ==="
      echo "WARNING: All config is HARDCODED in the image!"
      echo ""
      echo "Database Host: dev-db.internal.local"
      echo "Database User: dev_user"
      echo "Database Pass: dev_password_123"
      echo "Environment: development"
      echo "Debug Mode: enabled"
      echo ""
      echo "Serving customers with DEV settings... OOPS!"
      sleep 3600
  restartPolicy: Never
EOF

kubectl apply -f shopfast-bad.yaml
```

#### Step 2: Observe the Problem

```bash
# Wait for pod to start
kubectl wait --for=condition=Ready pod/shopfast-bad --timeout=30s

# Check the logs - see the hardcoded dev credentials!
kubectl logs shopfast-bad
```

**🔍 What You Should See**: The application is exposing development credentials. In a real scenario, this would connect to the wrong database!

#### Step 3: Understand Why This is Bad

```bash
# Anyone with kubectl access can see these credentials
kubectl get pod shopfast-bad -o yaml | grep -A 20 "command:"

# Even worse - these are baked into the image history
echo "In real Docker images, 'docker history' would reveal secrets in build layers!"
```

**📝 Key Learning**: Hardcoding configuration means:
- ❌ Rebuilding images for every environment
- ❌ Secrets exposed in image layers
- ❌ Same image cannot be used in dev/staging/prod
- ❌ Security audit nightmare

#### Step 4: Clean Up the Bad Deployment

```bash
kubectl delete pod shopfast-bad
rm shopfast-bad.yaml
echo "✓ Bad deployment removed. Let's do this properly!"
```

---

### Exercise 2: Separating Configuration from Code (ConfigMaps)

**Scenario**: The CTO mandates: "No more hardcoded configs!" You need to externalize the ShopFast application settings so the same container image works in any environment.

**Your Task**: Create a ConfigMap for non-sensitive settings and deploy ShopFast properly.

#### Step 1: Create the Application ConfigMap

```bash
cat > shopfast-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopfast-config
  labels:
    app: shopfast
    component: config
data:
  # Application Settings
  APP_NAME: "ShopFast"
  APP_VERSION: "2.1.0"
  
  # Environment Settings
  ENVIRONMENT: "production"
  DEBUG_MODE: "false"
  LOG_LEVEL: "info"
  
  # Feature Flags
  FEATURE_NEW_CHECKOUT: "true"
  FEATURE_DARK_MODE: "true"
  FEATURE_AI_RECOMMENDATIONS: "false"
  
  # External Service URLs (non-sensitive)
  PAYMENT_GATEWAY_URL: "https://payments.shopfast.com/api"
  SHIPPING_API_URL: "https://shipping.shopfast.com/api"
  CDN_URL: "https://cdn.shopfast.com"
EOF

kubectl apply -f shopfast-config.yaml
```

#### Step 2: Verify the ConfigMap was Created

```bash
# List all ConfigMaps
kubectl get configmaps

# View the ConfigMap details
kubectl describe configmap shopfast-config

# See the actual data
kubectl get configmap shopfast-config -o yaml
```

**🔍 What You Should See**: All your configuration data stored as key-value pairs, visible but separate from any container.

#### Step 3: Deploy ShopFast Using the ConfigMap

```bash
cat > shopfast-app.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shopfast-api
  labels:
    app: shopfast
    component: api
spec:
  containers:
  - name: api
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "╔════════════════════════════════════════════╗"
      echo "║     ShopFast API - Production Server       ║"
      echo "╚════════════════════════════════════════════╝"
      echo ""
      echo "📦 Application: $APP_NAME v$APP_VERSION"
      echo "🌍 Environment: $ENVIRONMENT"
      echo "🐛 Debug Mode:  $DEBUG_MODE"
      echo "📊 Log Level:   $LOG_LEVEL"
      echo ""
      echo "🚀 Feature Flags:"
      echo "   • New Checkout: $FEATURE_NEW_CHECKOUT"
      echo "   • Dark Mode:    $FEATURE_DARK_MODE"
      echo "   • AI Recommend: $FEATURE_AI_RECOMMENDATIONS"
      echo ""
      echo "🔗 External Services:"
      echo "   • Payments: $PAYMENT_GATEWAY_URL"
      echo "   • Shipping: $SHIPPING_API_URL"
      echo "   • CDN:      $CDN_URL"
      echo ""
      echo "✅ Configuration loaded from ConfigMap!"
      echo "Server running... (Ctrl+C to stop)"
      sleep 3600
    envFrom:
    - configMapRef:
        name: shopfast-config
  restartPolicy: Never
EOF

kubectl apply -f shopfast-app.yaml
```

#### Step 4: Verify Configuration is Loaded Correctly

```bash
# Wait for the pod
kubectl wait --for=condition=Ready pod/shopfast-api --timeout=30s

# Check the application output
kubectl logs shopfast-api
```

**🔍 What You Should See**: The application displays all configuration values loaded from the ConfigMap - NOT hardcoded!

#### Step 5: Verify Environment Variables Inside the Container

```bash
# Exec into the container and check env vars
kubectl exec shopfast-api -- env | grep -E "APP_|ENVIRONMENT|DEBUG|LOG_|FEATURE_|URL" | sort
```

**📝 Key Learning**: 
- ✅ Configuration is external to the image
- ✅ Same image can run anywhere
- ✅ Easy to update without rebuilding
- ✅ Configuration is auditable via kubectl

---

### Exercise 3: Securing Sensitive Data (Secrets)

**Scenario**: Great progress! But the security team flags an issue: "Database credentials and API keys should NEVER be in ConfigMaps - they're stored in plain text!" You need to use Kubernetes Secrets for sensitive data.

**Your Task**: Create Secrets for database credentials and API keys, then update ShopFast to use them.

#### Step 1: Understand Why Secrets Matter

```bash
# ConfigMap data is stored in plain text in etcd
# Anyone with API access can read it
kubectl get configmap shopfast-config -o jsonpath='{.data}' | head -c 200
echo "..."
echo ""
echo "⚠️  This is fine for non-sensitive data, but NOT for passwords!"
```

#### Step 2: Create Database Credentials Secret

```bash
cat > shopfast-db-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: shopfast-db-credentials
  labels:
    app: shopfast
    component: database
type: Opaque
stringData:
  # Using stringData for convenience (auto-encodes to base64)
  DB_HOST: "prod-db.shopfast.internal"
  DB_PORT: "5432"
  DB_NAME: "shopfast_production"
  DB_USER: "shopfast_app"
  DB_PASSWORD: "Pr0d$ecureP@ss#2024!"
EOF

kubectl apply -f shopfast-db-secret.yaml
```

#### Step 3: Create API Keys Secret

```bash
cat > shopfast-api-keys.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: shopfast-api-keys
  labels:
    app: shopfast
    component: integrations
type: Opaque
stringData:
  STRIPE_SECRET_KEY: "sk_live_51ABC123XYZ789..."
  SENDGRID_API_KEY: "SG.abcdef123456..."
  AWS_ACCESS_KEY_ID: "AKIAIOSFODNN7EXAMPLE"
  AWS_SECRET_ACCESS_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE"
EOF

kubectl apply -f shopfast-api-keys.yaml
```

#### Step 4: Verify Secrets are Protected

```bash
# List secrets
kubectl get secrets | grep shopfast

# Describe shows metadata but NOT the values!
kubectl describe secret shopfast-db-credentials
echo ""
echo "👆 Notice: Values are NOT displayed with 'describe'!"
```

#### Step 5: Understand Base64 Encoding (Not Encryption!)

```bash
# View the raw secret - data is base64 encoded
kubectl get secret shopfast-db-credentials -o yaml

echo ""
echo "⚠️  IMPORTANT: Base64 is ENCODING, not ENCRYPTION!"
echo "Anyone with kubectl access can decode it:"
echo ""

# Decode the password (demonstrating the security limitation)
kubectl get secret shopfast-db-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode
echo ""
```

**📝 Key Learning**: Base64 encoding is **NOT** security. It's just encoding for safe storage. Real security comes from RBAC, encryption at rest, and external secret managers.

#### Step 6: Deploy ShopFast with Both ConfigMap and Secrets

```bash
cat > shopfast-secure.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shopfast-secure
  labels:
    app: shopfast
    component: api
    version: secure
spec:
  containers:
  - name: api
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "╔════════════════════════════════════════════╗"
      echo "║   ShopFast API - Secure Configuration      ║"
      echo "╚════════════════════════════════════════════╝"
      echo ""
      echo "📦 App: $APP_NAME v$APP_VERSION ($ENVIRONMENT)"
      echo ""
      echo "🔐 Database Connection (from Secret):"
      echo "   Host: $DB_HOST"
      echo "   Port: $DB_PORT"
      echo "   Name: $DB_NAME"
      echo "   User: $DB_USER"
      echo "   Pass: ******* (hidden for security)"
      echo ""
      echo "🔑 API Keys Loaded (from Secret):"
      echo "   Stripe:    ${STRIPE_SECRET_KEY:0:10}... ✓"
      echo "   SendGrid:  ${SENDGRID_API_KEY:0:5}... ✓"
      echo "   AWS Key:   ${AWS_ACCESS_KEY_ID:0:8}... ✓"
      echo ""
      echo "✅ Secure configuration loaded!"
      echo "✅ Sensitive data from Secrets"
      echo "✅ Non-sensitive data from ConfigMap"
      sleep 3600
    envFrom:
    # Non-sensitive configuration
    - configMapRef:
        name: shopfast-config
    # Sensitive database credentials
    - secretRef:
        name: shopfast-db-credentials
    # Sensitive API keys
    - secretRef:
        name: shopfast-api-keys
  restartPolicy: Never
EOF

kubectl apply -f shopfast-secure.yaml
kubectl wait --for=condition=Ready pod/shopfast-secure --timeout=30s
kubectl logs shopfast-secure
```

**🔍 What You Should See**: The application loads configuration from ConfigMap AND secrets. Sensitive values are masked in output!

#### Step 7: Clean Up This Exercise

```bash
kubectl delete pod shopfast-api shopfast-secure
echo "✓ Pods cleaned up. ConfigMap and Secrets retained for next exercise."
```

---

### Exercise 4: Configuration Files via Volume Mounts

**Scenario**: The ShopFast application also needs configuration files (not just environment variables). The operations team wants to provide an `nginx.conf` for the web frontend and a `logging.json` for structured logging configuration.

**Your Task**: Mount ConfigMaps and Secrets as files in the container filesystem.

#### Step 1: Create ConfigMap with Configuration Files

```bash
cat > shopfast-files-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopfast-files
  labels:
    app: shopfast
    component: config-files
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        # Logging format for ShopFast
        log_format shopfast '$remote_addr - $request_id [$time_local] '
                            '"$request" $status $body_bytes_sent '
                            '"$http_referer" "$http_user_agent"';
        
        server {
            listen 80;
            server_name shopfast.com;
            
            # Health check endpoint
            location /health {
                return 200 '{"status": "healthy", "service": "shopfast-web"}';
                add_header Content-Type application/json;
            }
            
            # Main application
            location / {
                proxy_pass http://localhost:3000;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
        }
    }
  
  logging.json: |
    {
      "version": 1,
      "appName": "shopfast",
      "outputs": [
        {
          "type": "stdout",
          "format": "json"
        },
        {
          "type": "file",
          "path": "/var/log/shopfast/app.log",
          "maxSize": "100MB",
          "maxBackups": 5
        }
      ],
      "levels": {
        "default": "info",
        "database": "warn",
        "http": "debug"
      }
    }
  
  features.yaml: |
    features:
      new_checkout:
        enabled: true
        rollout_percentage: 100
      dark_mode:
        enabled: true
        default: false
      ai_recommendations:
        enabled: false
        model_version: "v2.1"
EOF

kubectl apply -f shopfast-files-config.yaml
```

#### Step 2: Create Secret with Sensitive Files

```bash
cat > shopfast-files-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: shopfast-certs
  labels:
    app: shopfast
    component: certificates
type: Opaque
stringData:
  # In real scenarios, these would be actual certificate contents
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiUMA0Gcg...
    (Production TLS Certificate for shopfast.com)
    -----END CERTIFICATE-----
  
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASC...
    (Private Key - KEEP SECURE!)
    -----END PRIVATE KEY-----
  
  db-ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDBjCCAe6gAwIBAgIBATANBgkqhk...
    (Database CA Certificate for SSL connections)
    -----END CERTIFICATE-----
EOF

kubectl apply -f shopfast-files-secret.yaml
```

#### Step 3: Deploy with Volume Mounts

```bash
cat > shopfast-with-files.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shopfast-web
  labels:
    app: shopfast
    component: web
spec:
  containers:
  - name: web
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "╔════════════════════════════════════════════╗"
      echo "║   ShopFast Web - Configuration Files       ║"
      echo "╚════════════════════════════════════════════╝"
      echo ""
      
      echo "📁 Configuration Files Mounted:"
      echo ""
      
      echo "━━━ /etc/nginx/nginx.conf ━━━"
      head -15 /etc/nginx/nginx.conf
      echo "... (truncated)"
      echo ""
      
      echo "━━━ /config/logging.json ━━━"
      cat /config/logging.json | head -10
      echo "... (truncated)"
      echo ""
      
      echo "━━━ /config/features.yaml ━━━"
      cat /config/features.yaml
      echo ""
      
      echo "🔐 Certificate Files (with secure permissions):"
      ls -la /certs/
      echo ""
      
      echo "📋 Certificate Details:"
      echo "   TLS Cert: $(wc -c < /certs/tls.crt) bytes"
      echo "   TLS Key:  $(wc -c < /certs/tls.key) bytes (PROTECTED)"
      echo "   DB CA:    $(wc -c < /certs/db-ca.crt) bytes"
      echo ""
      
      echo "✅ All configuration files mounted successfully!"
      sleep 3600
    volumeMounts:
    # Mount nginx.conf to specific path using subPath
    - name: config-files
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
    # Mount other config files to /config directory
    - name: config-files
      mountPath: /config
    # Mount certificates with restricted permissions
    - name: certs
      mountPath: /certs
      readOnly: true
  volumes:
  - name: config-files
    configMap:
      name: shopfast-files
  - name: certs
    secret:
      secretName: shopfast-certs
      defaultMode: 0400  # Read-only for owner only!
EOF

kubectl apply -f shopfast-with-files.yaml
kubectl wait --for=condition=Ready pod/shopfast-web --timeout=30s
kubectl logs shopfast-web
```

#### Step 4: Verify File Permissions for Secrets

```bash
echo "🔐 Verifying secure file permissions on certificates:"
echo ""
kubectl exec shopfast-web -- ls -la /certs/
echo ""
echo "👆 Notice: Permissions are 0400 (read-only, owner only)"
echo "   This prevents other processes from reading sensitive keys!"
```

#### Step 5: Compare with ConfigMap Permissions

```bash
echo "📁 ConfigMap files have standard permissions:"
kubectl exec shopfast-web -- ls -la /config/
echo ""
echo "👆 Notice: ConfigMap files are world-readable (0644)"
echo "   This is fine for non-sensitive configuration!"
```

**📝 Key Learning**:
- ✅ ConfigMaps and Secrets can be mounted as files
- ✅ Use `subPath` to mount individual files without replacing directories
- ✅ Use `defaultMode` to set secure permissions on sensitive files
- ✅ Secrets mounted as volumes are stored in tmpfs (memory), not disk

---

### Exercise 5: Live Configuration Updates (The Marketing Emergency)

**Scenario**: It's Black Friday! Marketing just announced a flash sale, but they forgot to tell engineering. You need to IMMEDIATELY enable a new "FLASH_SALE" feature flag and update the discount percentage - WITHOUT redeploying the application!

**Your Task**: Update a ConfigMap and observe how changes propagate to running Pods.

#### Step 1: Deploy the ShopFast Promotions Service

```bash
cat > shopfast-promos-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopfast-promos
  labels:
    app: shopfast
    component: promotions
data:
  FLASH_SALE_ENABLED: "false"
  FLASH_SALE_DISCOUNT: "0"
  FLASH_SALE_MESSAGE: "No active sales"
  promotions.conf: |
    # ShopFast Promotions Configuration
    # Last updated: Before Black Friday
    
    flash_sale {
        enabled = false
        discount_percent = 0
        banner_message = "No active promotions"
        end_time = ""
    }
EOF

kubectl apply -f shopfast-promos-config.yaml
```

```bash
cat > shopfast-promos-app.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfast-promos
  labels:
    app: shopfast
    component: promotions
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shopfast-promos
  template:
    metadata:
      labels:
        app: shopfast-promos
    spec:
      containers:
      - name: promos
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "🛍️  ShopFast Promotions Service Started"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo ""
          COUNTER=0
          while true; do
            COUNTER=$((COUNTER + 1))
            echo ""
            echo "═══════════════════════════════════════"
            echo "📊 Status Check #$COUNTER ($(date +%H:%M:%S))"
            echo "═══════════════════════════════════════"
            echo ""
            echo "📢 ENV VARIABLES (set at pod start):"
            echo "   Flash Sale Enabled:  $FLASH_SALE_ENABLED"
            echo "   Discount:            $FLASH_SALE_DISCOUNT%"
            echo "   Message:             $FLASH_SALE_MESSAGE"
            echo ""
            echo "📁 CONFIG FILE (live from volume):"
            grep -E "enabled|discount_percent|banner_message" /config/promotions.conf
            echo ""
            sleep 15
          done
        env:
        - name: FLASH_SALE_ENABLED
          valueFrom:
            configMapKeyRef:
              name: shopfast-promos
              key: FLASH_SALE_ENABLED
        - name: FLASH_SALE_DISCOUNT
          valueFrom:
            configMapKeyRef:
              name: shopfast-promos
              key: FLASH_SALE_DISCOUNT
        - name: FLASH_SALE_MESSAGE
          valueFrom:
            configMapKeyRef:
              name: shopfast-promos
              key: FLASH_SALE_MESSAGE
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: shopfast-promos
EOF

kubectl apply -f shopfast-promos-app.yaml
kubectl rollout status deployment shopfast-promos
```

#### Step 2: Observe Current Configuration

```bash
echo "📋 Current promotions status (before update):"
echo ""
kubectl logs -l app=shopfast-promos --tail=20
```

**🔍 What You Should See**: Flash sale is disabled, 0% discount.

#### Step 3: 🚨 EMERGENCY! Enable Black Friday Sale!

```bash
echo ""
echo "🚨🚨🚨 MARKETING EMERGENCY! 🚨🚨🚨"
echo "Enable Black Friday Flash Sale NOW!"
echo ""

kubectl patch configmap shopfast-promos --type merge -p '{
  "data": {
    "FLASH_SALE_ENABLED": "true",
    "FLASH_SALE_DISCOUNT": "50",
    "FLASH_SALE_MESSAGE": "🔥 BLACK FRIDAY FLASH SALE - 50% OFF EVERYTHING! 🔥",
    "promotions.conf": "# ShopFast Promotions Configuration\n# UPDATED: Black Friday Emergency!\n\nflash_sale {\n    enabled = true\n    discount_percent = 50\n    banner_message = \"BLACK FRIDAY FLASH SALE - 50% OFF!\"\n    end_time = \"2024-11-30T23:59:59Z\"\n}"
  }
}'

echo "✅ ConfigMap updated!"
```

#### Step 4: Observe What Updates and What Doesn't

```bash
echo ""
echo "⏳ Waiting 30 seconds for volume sync..."
echo "   (Volume mounts update automatically, env vars do NOT)"
echo ""
sleep 30

echo "📋 Checking promotions status AFTER ConfigMap update:"
echo ""
kubectl logs -l app=shopfast-promos --tail=25
```

**🔍 Critical Observation**: 
- **CONFIG FILE**: Updated automatically! Shows the new Black Friday settings!
- **ENV VARIABLES**: Still show old values! They were set when the Pod started!

#### Step 5: Understanding the Update Behavior

```bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 KEY LEARNING: ConfigMap Update Propagation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ VOLUME MOUNTS: Update automatically (~30-60 seconds)"
echo "   → Great for config files that apps reload dynamically"
echo ""
echo "❌ ENVIRONMENT VARS: Do NOT update (Pod restart required)"
echo "   → Env vars are set once when container starts"
echo ""
echo "💡 Best Practice: Use volume mounts for configs that"
echo "   need live updates. Use env vars for startup configs."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

#### Step 6: Force Update Environment Variables (Pod Restart)

```bash
echo ""
echo "🔄 Restarting deployment to pick up env var changes..."
kubectl rollout restart deployment shopfast-promos
kubectl rollout status deployment shopfast-promos

echo ""
echo "📋 Status after restart:"
kubectl logs -l app=shopfast-promos --tail=20
```

**🔍 What You Should See**: NOW both environment variables AND config files show the Black Friday sale settings!

**📝 Key Learning**:
- Volume-mounted ConfigMaps update automatically (with delay)
- Environment variables require Pod restart
- Design your apps to reload config files for dynamic updates
- Use `kubectl rollout restart` for env var updates

---

### Exercise 6: Multi-Environment Deployment (Dev vs Production)

**Scenario**: ShopFast needs to run in both development and production environments. The same Docker image should work in both, with different configurations. This is the "build once, deploy anywhere" principle.

**Your Task**: Create environment-specific ConfigMaps and Secrets, then demonstrate switching between them.

#### Step 1: Create Development Configuration

```bash
cat > shopfast-dev.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopfast-config-dev
  labels:
    app: shopfast
    environment: development
data:
  ENVIRONMENT: "development"
  DEBUG_MODE: "true"
  LOG_LEVEL: "debug"
  API_URL: "http://localhost:8080"
  DATABASE_SSL: "false"
  CACHE_ENABLED: "false"
---
apiVersion: v1
kind: Secret
metadata:
  name: shopfast-secrets-dev
  labels:
    app: shopfast
    environment: development
type: Opaque
stringData:
  DB_HOST: "localhost"
  DB_PORT: "5432"
  DB_NAME: "shopfast_dev"
  DB_USER: "dev_user"
  DB_PASSWORD: "dev_password"
  API_KEY: "dev_key_not_for_production"
EOF

kubectl apply -f shopfast-dev.yaml
```

#### Step 2: Create Production Configuration

```bash
cat > shopfast-prod.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopfast-config-prod
  labels:
    app: shopfast
    environment: production
data:
  ENVIRONMENT: "production"
  DEBUG_MODE: "false"
  LOG_LEVEL: "warn"
  API_URL: "https://api.shopfast.com"
  DATABASE_SSL: "true"
  CACHE_ENABLED: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: shopfast-secrets-prod
  labels:
    app: shopfast
    environment: production
type: Opaque
stringData:
  DB_HOST: "prod-db.shopfast.internal"
  DB_PORT: "5432"
  DB_NAME: "shopfast_production"
  DB_USER: "shopfast_prod"
  DB_PASSWORD: "Sup3r$ecur3Pr0dP@ss!"
  API_KEY: "prod_live_key_abc123xyz789"
EOF

kubectl apply -f shopfast-prod.yaml
```

#### Step 3: Create the Deployment Template

```bash
cat > shopfast-deployment.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shopfast-ENV_PLACEHOLDER
  labels:
    app: shopfast
    environment: ENV_PLACEHOLDER
spec:
  containers:
  - name: api
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "╔════════════════════════════════════════════╗"
      echo "║        ShopFast - Environment Check        ║"
      echo "╚════════════════════════════════════════════╝"
      echo ""
      echo "🌍 Running in: $ENVIRONMENT"
      echo ""
      echo "📋 Configuration:"
      echo "   Debug Mode:    $DEBUG_MODE"
      echo "   Log Level:     $LOG_LEVEL"
      echo "   API URL:       $API_URL"
      echo "   Database SSL:  $DATABASE_SSL"
      echo "   Cache:         $CACHE_ENABLED"
      echo ""
      echo "🔐 Database Connection:"
      echo "   Host:     $DB_HOST"
      echo "   Port:     $DB_PORT"
      echo "   Database: $DB_NAME"
      echo "   User:     $DB_USER"
      echo "   Password: ******* (${#DB_PASSWORD} chars)"
      echo ""
      if [ "$ENVIRONMENT" = "production" ]; then
        echo "⚠️  PRODUCTION MODE - Extra security enabled"
        echo "   • Debug disabled"
        echo "   • SSL required"
        echo "   • Full logging"
      else
        echo "🔧 DEVELOPMENT MODE - Developer friendly"
        echo "   • Debug enabled"
        echo "   • Verbose logging"
        echo "   • Local resources"
      fi
      echo ""
      sleep 3600
    envFrom:
    - configMapRef:
        name: shopfast-config-ENV_PLACEHOLDER
    - secretRef:
        name: shopfast-secrets-ENV_PLACEHOLDER
  restartPolicy: Never
EOF
```

#### Step 4: Deploy to Development Environment

```bash
# Create dev deployment from template
sed 's/ENV_PLACEHOLDER/dev/g' shopfast-deployment.yaml > shopfast-dev-pod.yaml
kubectl apply -f shopfast-dev-pod.yaml
kubectl wait --for=condition=Ready pod/shopfast-dev --timeout=30s

echo ""
echo "🔧 DEVELOPMENT Environment:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl logs shopfast-dev
```

#### Step 5: Deploy to Production Environment

```bash
# Create prod deployment from template
sed 's/ENV_PLACEHOLDER/prod/g' shopfast-deployment.yaml > shopfast-prod-pod.yaml
kubectl apply -f shopfast-prod-pod.yaml
kubectl wait --for=condition=Ready pod/shopfast-prod --timeout=30s

echo ""
echo "🚀 PRODUCTION Environment:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl logs shopfast-prod
```

#### Step 6: Compare the Two Environments

```bash
echo ""
echo "═══════════════════════════════════════════════════════"
echo "📊 COMPARISON: Development vs Production"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Development Settings:"
kubectl exec shopfast-dev -- env | grep -E "ENVIRONMENT|DEBUG|LOG_LEVEL|DB_HOST" | sort
echo ""
echo "Production Settings:"
kubectl exec shopfast-prod -- env | grep -E "ENVIRONMENT|DEBUG|LOG_LEVEL|DB_HOST" | sort
echo ""
echo "💡 KEY INSIGHT: Same container image, different configs!"
echo "   This enables: dev → staging → production pipelines"
echo "═══════════════════════════════════════════════════════"
```

**📝 Key Learning**:
- ✅ One image, multiple environments
- ✅ Environment-specific ConfigMaps and Secrets
- ✅ No code changes between environments
- ✅ Easy to promote configurations through pipeline

---

### Final Exercise: Complete Cleanup and Review

**Scenario**: The ShopFast deployment exercises are complete. Time to clean up and review what you learned.

#### Step 1: Review All Resources Created

```bash
echo "📋 ShopFast Resources Created During Lab:"
echo ""
echo "ConfigMaps:"
kubectl get configmaps | grep shopfast
echo ""
echo "Secrets:"
kubectl get secrets | grep shopfast
echo ""
echo "Pods:"
kubectl get pods | grep shopfast
echo ""
echo "Deployments:"
kubectl get deployments | grep shopfast
```

#### Step 2: Clean Up All ShopFast Resources

```bash
echo "🧹 Cleaning up all ShopFast resources..."
echo ""

# Delete Pods
kubectl delete pod shopfast-web shopfast-dev shopfast-prod 2>/dev/null || true

# Delete Deployments
kubectl delete deployment shopfast-promos 2>/dev/null || true

# Delete ConfigMaps
kubectl delete configmap shopfast-config shopfast-files shopfast-promos \
  shopfast-config-dev shopfast-config-prod 2>/dev/null || true

# Delete Secrets  
kubectl delete secret shopfast-db-credentials shopfast-api-keys shopfast-certs \
  shopfast-secrets-dev shopfast-secrets-prod 2>/dev/null || true

# Clean up YAML files
rm -f shopfast-*.yaml

echo "✅ Cleanup complete!"
```

#### Step 3: Lab Summary

```bash
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║          🎓 LAB COMPLETE - KEY TAKEAWAYS 🎓            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Exercise 1: Hardcoded configs are dangerous"
echo "   → Separating config from code is essential"
echo ""
echo "✅ Exercise 2: ConfigMaps for non-sensitive data"
echo "   → Environment variables via envFrom"
echo "   → Centralized, auditable configuration"
echo ""
echo "✅ Exercise 3: Secrets for sensitive data"
echo "   → Base64 encoded (NOT encrypted)"
echo "   → Use stringData for convenience"
echo "   → RBAC controls who can access"
echo ""
echo "✅ Exercise 4: Volume mounts for config files"
echo "   → Use subPath for individual files"
echo "   → Use defaultMode for secure permissions"
echo "   → Secrets stored in tmpfs (memory)"
echo ""
echo "✅ Exercise 5: Live configuration updates"
echo "   → Volume mounts: Auto-update (~1 min)"
echo "   → Environment vars: Need Pod restart"
echo ""
echo "✅ Exercise 6: Multi-environment deployments"
echo "   → Same image, different configs"
echo "   → Build once, deploy anywhere"
echo ""
echo "🚀 You're now ready to manage Kubernetes configurations!"
echo "════════════════════════════════════════════════════════"
```

---

## Key Takeaways

### ConfigMaps

- **ConfigMaps** store non-sensitive configuration data
- Can be created from **literals**, **files**, or **YAML manifests**
- Used as **environment variables** or **mounted volumes**
- Volume-mounted ConfigMaps are **automatically updated** (with delay)
- Environment variables require **Pod restart** to pick up changes

### Secrets

- **Secrets** store sensitive data (passwords, tokens, keys)
- Data is **base64 encoded** (NOT encrypted by default)
- Use **stringData** for convenience (auto-encodes to base64)
- Multiple **types** for different use cases (Opaque, TLS, docker-registry)
- Mounted as **tmpfs** (memory) for security

### Best Practices

- Use **ConfigMaps** for non-sensitive configuration
- Use **Secrets** for sensitive data
- **Never** commit secrets to version control
- Consider **external secret management** for production
- Use **immutable** ConfigMaps/Secrets for critical configurations
- Set proper **file permissions** (defaultMode) for mounted secrets

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `kubectl create configmap <name> --from-literal=key=value` | Create ConfigMap from literal |
| `kubectl create configmap <name> --from-file=<file>` | Create ConfigMap from file |
| `kubectl create secret generic <name> --from-literal=key=value` | Create Secret from literal |
| `kubectl create secret generic <name> --from-file=<file>` | Create Secret from file |
| `kubectl create secret docker-registry <name> --docker-server=<url> --docker-username=<user> --docker-password=<pass>` | Create Docker registry secret |
| `kubectl create secret tls <name> --cert=<cert> --key=<key>` | Create TLS secret |
| `kubectl get configmaps` | List ConfigMaps |
| `kubectl get secrets` | List Secrets |
| `kubectl describe configmap <name>` | ConfigMap details |
| `kubectl describe secret <name>` | Secret details (values hidden) |
| `kubectl get secret <name> -o yaml` | View Secret with base64 values |
| `kubectl get secret <name> -o jsonpath='{.data.key}' \| base64 -d` | Decode Secret value |

### ConfigMap Manifest Template

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  # Simple key-value
  KEY: "value"
  
  # Multi-line file
  config.yaml: |
    setting1: value1
    setting2: value2
```

### Secret Manifest Template

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  # Plain text (auto-encoded)
  username: myuser
  password: mypassword
```

### Pod Using ConfigMap/Secret Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: myimage:tag
    # All keys as env vars
    envFrom:
    - configMapRef:
        name: my-config
    - secretRef:
        name: my-secret
    # Specific key as env var
    env:
    - name: SPECIFIC_KEY
      valueFrom:
        configMapKeyRef:
          name: my-config
          key: KEY
    - name: SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: password
    # Mount as volume
    volumeMounts:
    - name: config-volume
      mountPath: /config
    - name: secret-volume
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: my-config
  - name: secret-volume
    secret:
      secretName: my-secret
      defaultMode: 0400
```

---

## Cleanup (End of Lab)

```bash
# Delete all ConfigMaps created in this lab (Parts 1-9)
kubectl delete configmap app-config app-properties multi-file-config webapp-config \
  db-config app-settings nginx-config multi-config update-config immutable-config \
  nginx-custom 2>/dev/null || true

# Delete all Secrets created in this lab (Parts 1-9)
kubectl delete secret db-credentials file-credentials encoded-secret plaintext-secret \
  my-registry-secret my-tls-secret api-secret db-secret ssh-secret app-secrets \
  immutable-secret app-secret 2>/dev/null || true

# Delete all Pods created in this lab (Parts 1-9)
kubectl delete pod env-single-demo env-all-demo volume-demo selective-mount-demo \
  secret-env-single secret-env-all secret-volume-demo secret-selective update-demo \
  optional-demo combined-demo subpath-demo 2>/dev/null || true

# Delete ShopFast exercise resources
kubectl delete configmap shopfast-config shopfast-files shopfast-promos \
  shopfast-config-dev shopfast-config-prod 2>/dev/null || true
kubectl delete secret shopfast-db-credentials shopfast-api-keys shopfast-certs \
  shopfast-secrets-dev shopfast-secrets-prod 2>/dev/null || true
kubectl delete pod shopfast-bad shopfast-api shopfast-secure shopfast-web \
  shopfast-dev shopfast-prod 2>/dev/null || true
kubectl delete deployment shopfast-promos 2>/dev/null || true

# Remove lab directory and exercise files
cd ~
rm -rf ~/secrets-configmaps-lab
rm -f shopfast-*.yaml

# Verify cleanup
kubectl get configmaps
kubectl get secrets
kubectl get pods
```

---

## Troubleshooting Common Issues

### ConfigMap/Secret Not Found

```bash
# Check if ConfigMap exists
kubectl get configmap <name>

# Check if Secret exists
kubectl get secret <name>

# Common causes:
# - Typo in name
# - Created in wrong namespace
# - Not yet created

# Check namespace
kubectl get configmap <name> -n <namespace>
```

### Environment Variables Not Updating

```bash
# Environment variables are set at Pod creation
# They do NOT update when ConfigMap/Secret changes

# Solution: Restart the Pod
kubectl delete pod <name>

# For Deployments, use rollout restart
kubectl rollout restart deployment <name>
```

### Volume Mount Showing Old Data

```bash
# Volume mounts can take up to 1 minute to sync
# Check sync status
kubectl exec <pod> -- ls -la /config

# If using subPath, updates are NOT propagated
# Solution: Don't use subPath, or restart Pod
```

### Permission Denied on Mounted Files

```bash
# Check file permissions
kubectl exec <pod> -- ls -la /secrets

# Set defaultMode in volume spec
volumes:
- name: secret-volume
  secret:
    secretName: my-secret
    defaultMode: 0644  # Or 0400 for read-only by owner
```

### Base64 Encoding Issues

```bash
# Ensure no trailing newline when encoding
echo -n "myvalue" | base64  # -n prevents newline

# Decode to verify
echo "bXl2YWx1ZQ==" | base64 --decode

# Use stringData instead to avoid encoding issues
stringData:
  key: "value"  # Auto-encoded
```

### Secret Data Visible in YAML

```bash
# Secrets are base64 encoded, not encrypted
# Anyone with kubectl access can decode them

# Solutions:
# 1. Use RBAC to restrict access
# 2. Enable encryption at rest
# 3. Use external secret management (Vault, etc.)
```

---

## Additional Resources

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Managing Secrets](https://kubernetes.io/docs/tasks/configmap-secret/)
- [Encrypting Secrets at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [External Secrets Operator](https://external-secrets.io/)
