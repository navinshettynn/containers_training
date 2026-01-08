# Kubernetes Secrets and ConfigMaps – Test Questions

Use these questions to assess participant understanding after completing the Secrets and ConfigMaps lab.

---

## Section 1: Multiple Choice

**1. What is the primary purpose of a ConfigMap?**

a) To store sensitive data like passwords  
b) To store non-confidential configuration data in key-value pairs  
c) To encrypt application settings  
d) To manage container images  

---

**2. What is the primary purpose of a Secret?**

a) To store large binary files  
b) To store non-sensitive configuration  
c) To store sensitive data such as passwords, tokens, and keys  
d) To encrypt ConfigMaps  

---

**3. How is data stored in a Kubernetes Secret by default?**

a) Encrypted with AES-256  
b) Plain text  
c) Base64 encoded  
d) SHA-256 hashed  

---

**4. What is the maximum size limit for a ConfigMap or Secret?**

a) 100 KB  
b) 512 KB  
c) 1 MB  
d) 10 MB  

---

**5. Which command creates a ConfigMap from a literal key-value pair?**

a) `kubectl create configmap my-config --data=key=value`  
b) `kubectl create configmap my-config --from-literal=key=value`  
c) `kubectl create configmap my-config --literal key=value`  
d) `kubectl create configmap my-config --set key=value`  

---

**6. Which command creates a Secret from a file?**

a) `kubectl create secret file my-secret --file=password.txt`  
b) `kubectl create secret generic my-secret --from-file=password.txt`  
c) `kubectl create secret my-secret --data-file=password.txt`  
d) `kubectl create secret config my-secret --file=password.txt`  

---

**7. When using a ConfigMap as environment variables, which field loads all keys at once?**

a) `env`  
b) `envAll`  
c) `envFrom`  
d) `configMapEnv`  

---

**8. How do you reference a specific key from a ConfigMap as an environment variable?**

a) `secretKeyRef`  
b) `configMapKeyRef`  
c) `configMapRef`  
d) `keyRef`  

---

**9. When a ConfigMap is mounted as a volume, what happens when the ConfigMap is updated?**

a) Nothing, the mounted files never update  
b) The Pod automatically restarts  
c) The mounted files are eventually updated (with some delay)  
d) The ConfigMap cannot be updated once mounted  

---

**10. When a ConfigMap is used as environment variables, what happens when the ConfigMap is updated?**

a) Environment variables are updated automatically  
b) Environment variables are NOT updated (Pod restart required)  
c) The Pod crashes  
d) Environment variables update immediately  

---

**11. What is the default Secret type when creating a generic secret?**

a) `kubernetes.io/basic-auth`  
b) `kubernetes.io/tls`  
c) `Opaque`  
d) `kubernetes.io/service-account-token`  

---

**12. Which Secret type is used for Docker registry credentials?**

a) `kubernetes.io/docker-auth`  
b) `kubernetes.io/dockerconfigjson`  
c) `Opaque`  
d) `kubernetes.io/registry`  

---

**13. What field in a Secret manifest allows you to provide values in plain text (without base64 encoding)?**

a) `plainData`  
b) `textData`  
c) `stringData`  
d) `rawData`  

---

**14. How are Secrets mounted in a Pod's filesystem?**

a) As regular files on disk  
b) As tmpfs (memory-based filesystem)  
c) As encrypted files  
d) As symlinks to etcd  

---

**15. What does setting `immutable: true` on a ConfigMap or Secret do?**

a) Encrypts the data  
b) Prevents any modifications after creation  
c) Makes it read-only for Pods  
d) Hides it from kubectl get commands  

---

**16. What file permission should you typically use for mounted Secret files containing private keys?**

a) 0777 (read/write/execute for all)  
b) 0644 (read for all, write for owner)  
c) 0400 (read-only for owner)  
d) 0755 (read/execute for all, write for owner)  

---

**17. Which field in a volume mount allows you to mount a single file without replacing the entire directory?**

a) `singleFile`  
b) `mountPath`  
c) `subPath`  
d) `itemPath`  

---

**18. What happens if a Pod references a ConfigMap that doesn't exist?**

a) The Pod starts with empty environment variables  
b) The Pod fails to start  
c) The Pod starts but logs a warning  
d) The ConfigMap is automatically created  

---

**19. How can you make a ConfigMap or Secret reference optional?**

a) Set `required: false`  
b) Set `optional: true` in the reference  
c) Use `optionalConfigMapRef`  
d) ConfigMaps and Secrets cannot be optional  

---

**20. Which command decodes a base64-encoded Secret value?**

a) `kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 --encode`  
b) `kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 --decode`  
c) `kubectl get secret my-secret --decode`  
d) `kubectl describe secret my-secret --show-values`  

---

## Section 2: True or False

**21. Base64 encoding in Secrets provides encryption for sensitive data.**

☐ True  
☐ False  

---

**22. ConfigMaps and Secrets can both be used as environment variables and mounted volumes.**

☐ True  
☐ False  

---

**23. You can create a ConfigMap from multiple files in a directory using `--from-file=<directory>`.**

☐ True  
☐ False  

---

**24. When using subPath to mount a file, changes to the ConfigMap are automatically reflected in the mounted file.**

☐ True  
☐ False  

---

**25. The `stringData` field in a Secret manifest is automatically converted to base64-encoded `data` when created.**

☐ True  
☐ False  

---

**26. ConfigMaps can store binary data.**

☐ True  
☐ False  

---

**27. Secrets are encrypted by default in etcd.**

☐ True  
☐ False  

---

**28. You can use both `envFrom` (for all keys) and `env` (for specific keys) in the same container spec.**

☐ True  
☐ False  

---

**29. Immutable ConfigMaps and Secrets improve cluster performance by reducing API server load.**

☐ True  
☐ False  

---

**30. The `kubectl describe secret` command shows the actual secret values.**

☐ True  
☐ False  

---

## Section 3: Fill in the Blank

**31. Complete the command to create a ConfigMap from a file named `app.conf`:**

```bash
kubectl create configmap my-config __________=app.conf
```

---

**32. Complete the Pod spec to use all keys from a ConfigMap as environment variables:**

```yaml
envFrom:
- __________:
    name: my-config
```

---

**33. Complete the command to view the decoded value of the `password` key from a Secret:**

```bash
kubectl get secret my-secret -o jsonpath='{.data.password}' | __________ --decode
```

---

**34. Complete the Secret manifest to create a TLS secret type:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: __________
```

---

**35. Complete the volume spec to mount only the `config.yaml` key from a ConfigMap:**

```yaml
volumes:
- name: config-volume
  configMap:
    name: my-config
    __________:
    - key: config.yaml
      path: app-config.yaml
```

---

**36. To prevent a ConfigMap from being modified after creation, set __________ to true.**

---

**37. Complete the command to create a Docker registry secret:**

```bash
kubectl create secret __________ my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

---

**38. Complete the volume mount to set file permissions to read-only for owner (0400):**

```yaml
volumes:
- name: secret-volume
  secret:
    secretName: my-secret
    __________: 0400
```

---

**39. In a Secret manifest, the __________ field allows you to specify plain text values without base64 encoding.**

---

**40. Complete the env var spec to make the ConfigMap reference optional:**

```yaml
env:
- name: MY_VAR
  valueFrom:
    configMapKeyRef:
      name: might-not-exist
      key: some-key
      __________: true
```

---

## Section 4: Short Answer

**41. Explain the difference between ConfigMaps and Secrets. When would you use each?**

---

**42. What are three ways to create a ConfigMap? Provide the kubectl commands for each.**

---

**43. Explain the difference between using `data` and `stringData` in a Secret manifest.**

---

**44. Why are volume-mounted ConfigMap files updated automatically but environment variables are not?**

---

**45. List three Kubernetes Secret types and explain when you would use each.**

---

**46. What security considerations should you be aware of when using Kubernetes Secrets?**

---

**47. Explain what happens when you use `subPath` in a volume mount. What is the trade-off?**

---

**48. A team wants to use different configurations for development, staging, and production environments. How would you organize ConfigMaps for this use case?**

---

## Section 5: Practical Scenarios

**49. Write a ConfigMap manifest that:**
- Contains an application name and version as key-value pairs
- Contains a multi-line nginx configuration file

---

**50. Write a Secret manifest that:**
- Contains database credentials (username and password)
- Uses stringData for ease of creation

---

**51. Write a Pod manifest that:**
- Uses a ConfigMap for non-sensitive settings (APP_ENV, LOG_LEVEL)
- Uses a Secret for sensitive settings (DB_PASSWORD, API_KEY)
- Loads all keys from both as environment variables

---

**52. Write the commands to:**
1. Create a ConfigMap from a file named `config.properties`
2. Create a Secret from literals for username and password
3. View the ConfigMap contents
4. Decode and view the Secret password

---

**53. Write a Pod manifest that:**
- Mounts a ConfigMap containing nginx.conf to `/etc/nginx/nginx.conf`
- Uses subPath to avoid replacing the entire directory
- Mounts a TLS Secret to `/etc/nginx/ssl` with 0400 permissions

---

**54. Write the commands to troubleshoot a Pod that fails to start with error "configmap not found":**
1. Check Pod events
2. List ConfigMaps in the namespace
3. Verify ConfigMap name matches Pod spec
4. Create the missing ConfigMap if needed

---

**55. Write a Deployment manifest that:**
- Uses ConfigMap for application settings
- Uses Secret for database credentials
- Includes an annotation to trigger rollout on ConfigMap changes

---

**56. Write the commands to:**
1. Create an immutable ConfigMap
2. Attempt to update it (should fail)
3. Create a new ConfigMap with updated values
4. Update the Pod to use the new ConfigMap

---

---

## Answer Key

### Section 1: Multiple Choice

| Q | Answer | Explanation |
|---|--------|-------------|
| 1 | b | ConfigMaps store non-confidential configuration data |
| 2 | c | Secrets are designed for sensitive data like passwords and tokens |
| 3 | c | Secrets are base64 encoded (not encrypted by default) |
| 4 | c | Both ConfigMaps and Secrets have a 1 MB size limit |
| 5 | b | --from-literal creates from key=value pairs |
| 6 | b | kubectl create secret generic --from-file creates from files |
| 7 | c | envFrom loads all keys from a ConfigMap or Secret |
| 8 | b | configMapKeyRef references a specific ConfigMap key |
| 9 | c | Mounted files are eventually updated (kubelet sync period) |
| 10 | b | Environment variables are set at Pod creation and don't update |
| 11 | c | Opaque is the default Secret type for generic secrets |
| 12 | b | kubernetes.io/dockerconfigjson is for registry credentials |
| 13 | c | stringData allows plain text values that are auto-encoded |
| 14 | b | Secrets are mounted as tmpfs (not written to disk) |
| 15 | b | immutable: true prevents any changes after creation |
| 16 | c | 0400 (read-only for owner) is most secure for private keys |
| 17 | c | subPath mounts a single file without replacing directory |
| 18 | b | Pod fails to start if required ConfigMap doesn't exist |
| 19 | b | Set optional: true in the configMapKeyRef or secretKeyRef |
| 20 | b | Use base64 --decode to decode the value |

### Section 2: True or False

| Q | Answer | Explanation |
|---|--------|-------------|
| 21 | False | Base64 is encoding, NOT encryption. Anyone can decode it. |
| 22 | True | Both can be used as env vars or mounted volumes |
| 23 | True | --from-file=<directory> creates keys from all files in dir |
| 24 | False | subPath prevents automatic updates on ConfigMap changes |
| 25 | True | stringData is converted to base64 data when created |
| 26 | True | ConfigMaps support binary data via binaryData field |
| 27 | False | Secrets are NOT encrypted by default; must enable encryption at rest |
| 28 | True | You can combine both methods in the same container |
| 29 | True | Immutable objects don't need watches, reducing API load |
| 30 | False | describe shows metadata but hides actual values |

### Section 3: Fill in the Blank

| Q | Answer |
|---|--------|
| 31 | `--from-file` |
| 32 | `configMapRef` |
| 33 | `base64` |
| 34 | `kubernetes.io/tls` |
| 35 | `items` |
| 36 | `immutable` |
| 37 | `docker-registry` |
| 38 | `defaultMode` |
| 39 | `stringData` |
| 40 | `optional` |

### Section 4: Short Answer

**41.** 
- **ConfigMap**: Stores non-sensitive configuration data in plain text. Use for application settings, feature flags, config files, URLs.
- **Secret**: Stores sensitive data with base64 encoding. Use for passwords, API keys, TLS certificates, SSH keys.

Key differences: Secrets are base64 encoded, mounted as tmpfs, can have RBAC restrictions, and have type-specific formats.

**42.** Three ways to create ConfigMaps:
```bash
# 1. From literals
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2

# 2. From file
kubectl create configmap my-config --from-file=config.properties

# 3. From YAML manifest
kubectl apply -f configmap.yaml
```

**43.** 
- **data**: Requires values to be base64 encoded. Use when values are already encoded or binary.
- **stringData**: Accepts plain text values. Kubernetes automatically encodes to base64 when creating. Easier for humans, good for YAML files.

When both are present for the same key, stringData takes precedence. In the stored Secret, only `data` exists (stringData is converted).

**44.** 
- **Volume mounts**: kubelet periodically syncs mounted ConfigMaps (default ~1 minute). Files are symlinks that can be atomically updated.
- **Environment variables**: Set once when the container starts. The process receives env vars at startup and doesn't re-read them. Container restart is needed for updates.

Note: subPath mounts don't receive updates because they're not symlinks.

**45.** Secret types:
1. **Opaque** (generic): User-defined data like passwords, API keys. Most common type.
2. **kubernetes.io/tls**: TLS certificates and keys. Requires `tls.crt` and `tls.key`. Used for HTTPS termination.
3. **kubernetes.io/dockerconfigjson**: Docker registry credentials. Used for pulling private images.
4. **kubernetes.io/basic-auth**: Username/password pairs for basic authentication.
5. **kubernetes.io/ssh-auth**: SSH private keys for Git operations.

**46.** Security considerations:
- Base64 is NOT encryption - anyone with API access can decode
- Enable RBAC to restrict who can read Secrets
- Enable encryption at rest (etcd encryption)
- Avoid committing Secrets to version control
- Use external secret management (HashiCorp Vault, AWS Secrets Manager)
- Secrets are stored in tmpfs but may appear in logs/events
- Set appropriate RBAC policies
- Rotate secrets regularly
- Audit secret access

**47.** subPath mounting:
- Mounts a single file/key instead of replacing entire directory
- Directory contents are preserved; only specified file is added
- **Trade-off**: Updates to the ConfigMap/Secret are NOT automatically reflected
- Use case: Adding a config file to a directory that has other needed files
- Alternative: Use init containers or separate volume mounts

**48.** Environment-specific ConfigMaps:
```bash
# Create per-environment ConfigMaps
kubectl create configmap app-config-dev --from-file=config/dev/
kubectl create configmap app-config-staging --from-file=config/staging/
kubectl create configmap app-config-prod --from-file=config/prod/

# Reference in Pod spec based on deployment:
# - Use different manifest files per environment
# - Use Helm values to template the ConfigMap name
# - Use Kustomize overlays for environment-specific configs
# - Use namespaces (dev/staging/prod) with same ConfigMap name
```

### Section 5: Practical Scenarios

**49.**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_NAME: "My Application"
  APP_VERSION: "1.0.0"
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        server {
            listen 80;
            server_name localhost;
            location / {
                root /usr/share/nginx/html;
                index index.html;
            }
        }
    }
```

**50.**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: S3cur3P@ssw0rd!
```

**51.**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    envFrom:
    - configMapRef:
        name: app-settings
    - secretRef:
        name: app-secrets
```

**52.**
```bash
# 1. Create ConfigMap from file
kubectl create configmap app-config --from-file=config.properties

# 2. Create Secret from literals
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password='S3cur3P@ss!'

# 3. View ConfigMap contents
kubectl get configmap app-config -o yaml

# 4. Decode Secret password
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 --decode
```

**53.**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-tls
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
    - name: tls-certs
      mountPath: /etc/nginx/ssl
      readOnly: true
  volumes:
  - name: nginx-config
    configMap:
      name: nginx-config
  - name: tls-certs
    secret:
      secretName: tls-secret
      defaultMode: 0400
```

**54.**
```bash
# 1. Check Pod events
kubectl describe pod <pod-name>

# 2. List ConfigMaps
kubectl get configmaps

# 3. Get Pod spec and verify ConfigMap name
kubectl get pod <pod-name> -o yaml | grep -A 5 configMap

# 4. Create missing ConfigMap
kubectl create configmap <configmap-name> --from-literal=key=value
# Or
kubectl apply -f configmap.yaml
```

**55.**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # Change this annotation value to trigger rollout on ConfigMap update
        configmap-version: "v1"
    spec:
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: db-credentials
```

**56.**
```bash
# 1. Create immutable ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config-v1
data:
  setting: "value1"
immutable: true
EOF

# 2. Try to update (will fail)
kubectl patch configmap immutable-config-v1 --type merge -p '{"data":{"setting":"value2"}}'
# Error: ConfigMap is immutable

# 3. Create new ConfigMap with updated values
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config-v2
data:
  setting: "value2"
immutable: true
EOF

# 4. Update Pod to use new ConfigMap
kubectl patch pod <pod-name> --type json -p='[{"op": "replace", "path": "/spec/containers/0/envFrom/0/configMapRef/name", "value": "immutable-config-v2"}]'
# Or update Deployment spec and apply
kubectl set env deployment/<deployment-name> --from=configmap/immutable-config-v2
```

---

## Scoring Guide

| Score | Level |
|-------|-------|
| 50-56 | Expert – Ready for advanced Kubernetes configuration management |
| 42-49 | Proficient – Solid understanding, minor gaps |
| 34-41 | Intermediate – Review ConfigMap and Secret concepts |
| 25-33 | Beginner – Review core configuration concepts |
| 0-24 | Needs Review – Retake the lab exercises |
