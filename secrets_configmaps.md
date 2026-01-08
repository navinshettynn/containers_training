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

## Exercises

### Exercise 1: Application Configuration

Create a complete application setup with ConfigMap for configuration:

```bash
cd ~/secrets-configmaps-lab

cat > exercise1.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-settings
data:
  APP_NAME: "My Web App"
  APP_PORT: "8080"
  FEATURE_DARK_MODE: "true"
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        server {
            listen 8080;
            location / {
                return 200 'Welcome to $APP_NAME\nDark Mode: $FEATURE_DARK_MODE\n';
                add_header Content-Type text/plain;
            }
        }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 8080
    envFrom:
    - configMapRef:
        name: webapp-settings
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:
  - name: nginx-config
    configMap:
      name: webapp-settings
EOF

kubectl apply -f exercise1.yaml
kubectl wait --for=condition=Ready pod/webapp --timeout=60s

# Test
kubectl port-forward webapp 8080:8080 &
sleep 2
curl localhost:8080
pkill -f "port-forward webapp"
```

Cleanup:

```bash
kubectl delete -f exercise1.yaml
```

### Exercise 2: Database Credentials with Secrets

Create a secure database configuration:

```bash
cat > exercise2.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:
  DB_HOST: "postgres.database.svc"
  DB_PORT: "5432"
  DB_NAME: "myapp"
---
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  DB_USER: "appuser"
  DB_PASSWORD: "P@ssw0rd123!"
---
apiVersion: v1
kind: Pod
metadata:
  name: db-client
spec:
  containers:
  - name: app
    image: busybox:latest
    command: 
    - sh
    - -c
    - |
      echo "Database Connection Info:"
      echo "Host: $DB_HOST"
      echo "Port: $DB_PORT"
      echo "Database: $DB_NAME"
      echo "User: $DB_USER"
      echo "Password: [HIDDEN]"
      sleep 3600
    envFrom:
    - configMapRef:
        name: db-config
    - secretRef:
        name: db-credentials
  restartPolicy: Never
EOF

kubectl apply -f exercise2.yaml
sleep 5
kubectl logs db-client
```

Cleanup:

```bash
kubectl delete -f exercise2.yaml
```

### Exercise 3: TLS Certificate Configuration

Create a Pod with TLS certificates mounted:

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com"

# Create the Secret
kubectl create secret tls myapp-tls --cert=tls.crt --key=tls.key

# Create Pod that uses the certificate
cat > exercise3.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tls-demo
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "ls -la /certs && openssl x509 -in /certs/tls.crt -text -noout | head -20 && sleep 3600"]
    volumeMounts:
    - name: tls-certs
      mountPath: /certs
      readOnly: true
  volumes:
  - name: tls-certs
    secret:
      secretName: myapp-tls
EOF

kubectl apply -f exercise3.yaml
sleep 5
kubectl logs tls-demo

# Cleanup cert files
rm tls.key tls.crt
```

Cleanup:

```bash
kubectl delete -f exercise3.yaml
kubectl delete secret myapp-tls
```

---

## Optional Advanced Exercises

### Exercise 4: Hot-Reload Configuration

Create a deployment that automatically picks up ConfigMap changes:

```bash
cat > exercise4.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: hot-reload-config
data:
  message.txt: "Hello, World! Version 1"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hot-reload-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hot-reload
  template:
    metadata:
      labels:
        app: hot-reload
    spec:
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "while true; do cat /config/message.txt; sleep 5; done"]
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: hot-reload-config
EOF

kubectl apply -f exercise4.yaml
kubectl rollout status deployment hot-reload-demo

# Watch logs
kubectl logs -f -l app=hot-reload &

# Update ConfigMap (in another terminal or wait a moment)
sleep 10
kubectl patch configmap hot-reload-config --type merge -p '{"data":{"message.txt":"Hello, World! Version 2 - Updated!"}}'

# Wait for sync (up to 1 minute)
sleep 60

# Stop log streaming
pkill -f "kubectl logs"
```

Cleanup:

```bash
kubectl delete -f exercise4.yaml
```

### Exercise 5: Environment-Specific Configuration

Create configurations for different environments:

```bash
# Development ConfigMap
cat > dev-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-dev
data:
  ENV: "development"
  DEBUG: "true"
  LOG_LEVEL: "debug"
  API_URL: "http://localhost:8080"
EOF

# Production ConfigMap
cat > prod-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-prod
data:
  ENV: "production"
  DEBUG: "false"
  LOG_LEVEL: "warn"
  API_URL: "https://api.example.com"
EOF

kubectl apply -f dev-config.yaml
kubectl apply -f prod-config.yaml

# Create Pod using dev config
cat > env-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: env-app
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "env | grep -E 'ENV|DEBUG|LOG|API' && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config-dev  # Change to app-config-prod for production
EOF

kubectl apply -f env-pod.yaml
sleep 5
kubectl logs env-app
```

Cleanup:

```bash
kubectl delete pod env-app
kubectl delete configmap app-config-dev app-config-prod
rm dev-config.yaml prod-config.yaml env-pod.yaml
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
# Delete all ConfigMaps created in this lab
kubectl delete configmap app-config app-properties multi-file-config webapp-config \
  db-config app-settings nginx-config multi-config update-config immutable-config \
  webapp-settings hot-reload-config app-config-dev app-config-prod nginx-custom 2>/dev/null || true

# Delete all Secrets created in this lab
kubectl delete secret db-credentials file-credentials encoded-secret plaintext-secret \
  my-registry-secret my-tls-secret api-secret db-secret ssh-secret app-secrets \
  immutable-secret app-secret myapp-tls 2>/dev/null || true

# Delete all Pods created in this lab
kubectl delete pod env-single-demo env-all-demo volume-demo selective-mount-demo \
  secret-env-single secret-env-all secret-volume-demo secret-selective update-demo \
  optional-demo combined-demo subpath-demo webapp db-client tls-demo env-app 2>/dev/null || true

# Delete Deployments
kubectl delete deployment hot-reload-demo 2>/dev/null || true

# Remove lab directory
cd ~
rm -rf ~/secrets-configmaps-lab

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
