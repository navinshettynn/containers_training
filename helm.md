# Helm Package Manager – Hands-on Lab (KIND Cluster)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **KIND (Kubernetes IN Docker)** clusters running on Ubuntu Linux VMs.

---

## Important: Lab Environment Setup

### Prerequisites

Before starting this lab, ensure:

1. Your Ubuntu VM has Docker installed and running
2. The KIND cluster has been created using the provided `install_kind.sh` script
3. **You have completed the previous labs** (kubectl Commands, Pods, Services, Deployments)
4. **If you completed the Service Meshes lab**, uninstall Istio first (see cleanup section in that lab)

> **Important**: This lab assumes familiarity with kubectl commands, Deployments, Services, ConfigMaps, and Secrets. If you haven't completed the previous labs, do those first.

> **⚠️ Bitnami Charts Notice**: Since August 2025, Bitnami has changed their licensing model. You may see warnings about "limited subset of images/charts available for free" during installations. These warnings do not prevent the lab from working, but some image pulls may be slower or show warnings. The core functionality remains the same for learning purposes.

### Verify Your Cluster is Running

```bash
# Check if kind cluster exists
# KIND creates a Kubernetes cluster inside Docker containers
kind get clusters

# Verify kubectl can communicate with the cluster
# This shows the API server and CoreDNS endpoints
kubectl cluster-info

# Check nodes are ready
# STATUS should be "Ready" for all nodes
kubectl get nodes
```

> **Why verify first?** Helm needs a working Kubernetes cluster to deploy charts. A misconfigured cluster will cause confusing installation failures. Always verify your environment before starting.

You should see output similar to:

```
NAME                         STATUS   ROLES           AGE   VERSION
kind-cluster-control-plane   Ready    control-plane   10m   v1.29.0
kind-cluster-worker          Ready    <none>          10m   v1.29.0
```

---

## Learning Objectives

### Core Helm Concepts

- Understand what **Helm** is and why it's needed
- Learn the key Helm concepts: **Charts**, **Releases**, **Repositories**
- Install and configure the **Helm CLI**
- Understand the **Chart structure** and key files

### Practical Skills

- **Search** for charts in repositories
- **Install** applications using Helm charts
- **Customize** installations with **values files** and `--set` flags
- **Upgrade** and **rollback** releases
- **Uninstall** releases and clean up
- **List** and **inspect** deployed releases

### Intermediate Objectives (Optional)

- **Create your own Helm chart** from scratch
- Use **templates** and **built-in functions**
- Understand **dependencies** and subcharts
- Use **Helm hooks** for lifecycle management
- **Package** and **share** charts

---

## Part 1: Understanding Helm

### What is Helm?

Helm is the **package manager for Kubernetes**. Think of it like `apt` for Ubuntu or `npm` for Node.js, but for Kubernetes applications.

> **Real-world problem**: Deploying a typical application requires multiple YAML files - Deployments, Services, ConfigMaps, Secrets, Ingress, etc. Managing these manually is error-prone, especially across multiple environments (dev, staging, production). Helm solves this by packaging everything together with configurable values.

| Feature | Description |
|---------|-------------|
| **Package Management** | Bundle K8s manifests into reusable packages (charts) |
| **Templating** | Use variables and logic in manifests |
| **Release Management** | Track installations, upgrades, and rollbacks |
| **Dependency Management** | Define and manage chart dependencies |

### Why Use Helm?

| Problem Without Helm | Helm Solution |
|---------------------|---------------|
| Managing many YAML files | Single chart packages everything |
| Repeating similar configs | Templates with variables |
| Tracking what's deployed | Release history and status |
| Environment differences | Values files per environment |
| Sharing configurations | Chart repositories |
| Complex upgrades | `helm upgrade` with rollback |

### Key Helm Concepts

| Concept | Description | Analogy |
|---------|-------------|---------|
| **Chart** | Package containing K8s resource templates | Software package (.deb, .rpm) |
| **Release** | Installed instance of a chart | Installed application |
| **Repository** | Collection of charts | Package repository (apt repo) |
| **Values** | Configuration for a chart | Config file / environment variables |

### Helm Architecture (v3)

```
┌─────────────────────────────────────────────────────────────┐
│                        Helm CLI                              │
│                           │                                  │
│            ┌──────────────┴──────────────┐                  │
│            ▼                              ▼                  │
│    ┌───────────────┐              ┌───────────────┐         │
│    │  Chart Repo   │              │  Kubernetes   │         │
│    │   (remote)    │              │    Cluster    │         │
│    └───────────────┘              └───────────────┘         │
│            │                              ▲                  │
│            │     helm install/upgrade     │                  │
│            └──────────────────────────────┘                  │
│                                                              │
│    No Tiller required (Helm v3)                             │
└─────────────────────────────────────────────────────────────┘
```

> **Note**: Helm v2 required a server-side component called Tiller that ran in the cluster with cluster-admin privileges. This was a security concern. Helm v3 removed Tiller entirely - the CLI communicates directly with the Kubernetes API using your kubeconfig credentials. This is more secure and simpler to manage.

**📝 Key Learning**: Helm simplifies Kubernetes deployments by packaging related resources together, providing templating for customization, and tracking release history for upgrades and rollbacks.

---

## Part 2: Installing Helm

### Check if Helm is Already Installed

```bash
# Check if Helm CLI is available and its version
# If installed, this shows version info; if not, you'll see "command not found"
helm version
```

If Helm is not installed, continue with the installation.

### Install Helm on Ubuntu

```bash
# Download and install the latest Helm
# This script detects your OS/architecture and installs the appropriate binary
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
# --short shows just the version number
helm version
```

Expected output:

```
version.BuildInfo{Version:"v3.x.x", GitCommit:"...", GitTreeState:"clean", GoVersion:"..."}
```

> **What the script does**: The install script downloads the appropriate Helm binary for your system, verifies its checksum, and installs it to `/usr/local/bin/helm`. It's the recommended installation method for most Linux systems.

### Alternative: Install Specific Version

```bash
# Download specific version
# Pinning versions ensures reproducibility across team members
HELM_VERSION="v3.14.0"
curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz

# Extract and install
# The archive contains a linux-amd64 directory with the helm binary
tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Cleanup downloaded files
rm -rf linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz

# Verify
helm version
```

> **Why pin versions?** In production environments, you want consistent tooling across all team members and CI/CD pipelines. Using a specific version prevents "works on my machine" issues.

### Configure Helm Autocomplete

```bash
# Enable bash completion for Helm commands
# This makes working with Helm much faster
echo 'source <(helm completion bash)' >> ~/.bashrc
source ~/.bashrc

# Test autocomplete (type "helm " and press Tab)
helm <TAB><TAB>
```

> **Productivity tip**: Tab completion saves time and helps discover available commands and flags. It's especially useful for long chart names and complex commands.

---

## Part 3: Working with Chart Repositories

### Understanding Repositories

Helm charts are stored in repositories. The most popular public repository is **ArtifactHub** (https://artifacthub.io/). Think of repositories like package registries - they host charts that you can search, download, and install.

> **Repository types**: 
> - **Public repositories** (Bitnami, Artifact Hub) - Maintained by the community or vendors
> - **Private repositories** (ChartMuseum, Harbor) - For internal/proprietary charts
> - **OCI registries** - Docker registries that also host Helm charts (newer approach)

### Add Popular Repositories

```bash
# Add the Bitnami repository (one of the most popular)
# Bitnami provides well-maintained charts for common applications
helm repo add bitnami https://charts.bitnami.com/bitnami

# Add the official stable charts (legacy, but still useful)
# Note: Many stable charts have moved to other repositories
helm repo add stable https://charts.helm.sh/stable

# Add the ingress-nginx repository
# This is the official NGINX Ingress Controller chart
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# List added repositories
# Shows name and URL of each configured repository
helm repo list
```

> **What happens when you add a repo**: Helm downloads the repository's `index.yaml` file, which contains metadata about all available charts, their versions, and dependencies. This index is cached locally for faster searches.

### Update Repository Cache

```bash
# Update repository index (like apt update)
# This refreshes the local cache with the latest chart versions
helm repo update
```

> **Why update regularly?** Chart maintainers release new versions frequently with bug fixes and security patches. Run `helm repo update` before installing or upgrading to ensure you're aware of the latest versions.

### Search for Charts

```bash
# Search in all added repositories
# This searches your local repository index cache
helm search repo nginx

# Search with more details
# -l lists ALL available versions, not just the latest
helm search repo nginx -l

# Search on ArtifactHub (online)
# This searches the public ArtifactHub registry directly
helm search hub wordpress
```

> **Local vs Hub search**: 
> - `helm search repo` - Searches only repositories you've added (fast, offline capable)
> - `helm search hub` - Searches ArtifactHub online (comprehensive, requires internet)

### View Chart Information

```bash
# Show chart details (name, version, description, maintainers)
# Useful to understand what you're about to install
helm show chart bitnami/nginx

# Show all information (chart metadata + values + readme)
# This is comprehensive but verbose
helm show all bitnami/nginx

# Show default values - THIS IS THE MOST IMPORTANT COMMAND
# These are all the configuration options you can customize
helm show values bitnami/nginx
```

> **Why `helm show values` matters**: Before installing any chart, always review its default values. This shows you what can be customized, what ports it uses, what resources it requests, and what features are enabled by default. This is your configuration reference.

### Remove a Repository

```bash
# Remove a repository
# Use this to clean up repositories you no longer need
helm repo remove stable
```

**📝 Key Learning**: Always run `helm show values <chart>` before installing to understand what you can customize. The values file is your primary interface for configuring Helm charts.

---

## Part 4: Installing Your First Chart

Now let's put theory into practice by installing our first Helm chart.

### Create a Lab Namespace

```bash
# Create a dedicated namespace for our Helm lab exercises
# Namespaces help organize and isolate resources
kubectl create namespace helm-lab
```

> **Why use namespaces?** Namespaces provide logical isolation. By installing in `helm-lab`, we keep our lab resources separate from other workloads and make cleanup easier.

### Install NGINX Using Helm

```bash
# Basic installation
# "my-nginx" is the RELEASE NAME - your unique identifier for this installation
# "bitnami/nginx" is the CHART - the package being installed
helm install my-nginx bitnami/nginx --namespace helm-lab

# Watch the deployment
# Helm created a Deployment, which creates a Pod
kubectl get pods -n helm-lab --watch
```

Press `Ctrl+C` when the pod is Running.

> **What just happened**: With a single command, Helm:
> 1. Downloaded the nginx chart from Bitnami repository
> 2. Rendered all templates with default values
> 3. Applied multiple Kubernetes resources (Deployment, Service, ConfigMap, etc.)
> 4. Created a "release" to track this installation

### Understand the Install Command

```
helm install <release-name> <chart-name> [flags]
           │               │
           │               └── Chart from repository (or local path)
           └── Your name for this installation (must be unique per namespace)
```

> **Release names matter**: The release name identifies your installation. You can install the same chart multiple times with different release names (e.g., `nginx-prod`, `nginx-staging`). Each becomes an independent release with its own resources and history.

### Check Release Status

```bash
# List all releases in the namespace
# Shows release name, namespace, revision, status, chart version
helm list -n helm-lab

# Get detailed release information
# Includes post-install notes with access instructions
helm status my-nginx -n helm-lab

# Get release history
# Shows all revisions - useful for tracking upgrades and rollbacks
helm history my-nginx -n helm-lab
```

> **What to look for in `helm status`**: The output includes:
> - Current deployment status
> - Resource names created
> - Post-install NOTES with instructions (how to access the app, default credentials, etc.)

### View Created Resources

```bash
# See what Helm created
# The label selector filters to only resources from this release
kubectl get all -n helm-lab -l app.kubernetes.io/instance=my-nginx
```

> **How Helm tracks resources**: Helm adds labels like `app.kubernetes.io/instance` to all resources it creates. This allows Helm to know which resources belong to which release during upgrades and uninstalls.

### Access the Application

```bash
# Port forward to test (runs in background)
# This maps local port 8080 to the service's port 80
kubectl port-forward -n helm-lab svc/my-nginx 8080:80 &
sleep 2

# Test the application
# Should return NGINX welcome page HTML
curl http://localhost:8080

# Stop port forwarding
pkill -f "port-forward.*my-nginx"
```

> **Why port-forward?** In KIND, we don't have a LoadBalancer. Port-forwarding lets us test services locally. In production with cloud providers, you'd use LoadBalancer or Ingress.

### Uninstall the Release

```bash
# Remove the release and all its resources
# This deletes the Deployment, Service, ConfigMap, etc.
helm uninstall my-nginx -n helm-lab

# Verify cleanup - should show no resources
kubectl get all -n helm-lab
```

> **What uninstall does**: Helm removes all Kubernetes resources that were created by the chart. The release history is also deleted by default (use `--keep-history` to preserve it).

**📝 Key Learning**: A single `helm install` command deploys complete applications with all their dependencies. A single `helm uninstall` removes everything cleanly. This is the power of package management for Kubernetes.

---

## Part 5: Customizing Installations with Values

This is where Helm's real power shines - customizing charts for your specific needs without modifying the chart itself.

### Understanding Values

Every Helm chart has a `values.yaml` file containing default configuration. You can override these values:

1. Using `--set` flag (command line) - Quick, one-off changes
2. Using `-f` or `--values` flag (values file) - Complex, reusable configurations

> **Values hierarchy** (highest to lowest priority):
> 1. `--set` flags on command line
> 2. `-f` values files (last file wins)
> 3. Chart's default `values.yaml`

### View Default Values

```bash
# Show all default values for nginx chart
# This is your configuration reference - study it carefully!
helm show values bitnami/nginx | head -100
```

> **What you'll see**: The output shows all configurable options - replica count, image settings, service configuration, resource limits, and more. Each option typically has comments explaining its purpose.

### Install with Custom Values (--set)

```bash
# Install with custom replica count and service type
# --set overrides specific values from the defaults
helm install custom-nginx bitnami/nginx \
  --namespace helm-lab \
  --set replicaCount=2 \
  --set service.type=ClusterIP

# Verify customization - should show 2 pods
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=custom-nginx

# Verify service type is ClusterIP (not LoadBalancer)
kubectl get svc -n helm-lab -l app.kubernetes.io/instance=custom-nginx
```

> **When to use `--set`**: Use `--set` for quick tests or simple overrides (1-3 values). For anything more complex, use a values file - it's more readable, version-controllable, and less error-prone.

### Install with Values File

```bash
# Create and navigate to lab directory
mkdir -p ~/helm-lab
cd ~/helm-lab

# Create a custom values file
# This file only needs to contain values you want to OVERRIDE
# NOTE: We don't override image settings to avoid Bitnami init container issues
cat > nginx-values.yaml <<'EOF'
# Custom values for nginx installation
# Only specify values you want to change from defaults

replicaCount: 3

service:
  type: NodePort
  nodePorts:
    http: 30080           # Fixed NodePort for predictable access

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"

# Custom labels for all resources
# Useful for filtering, cost allocation, etc.
commonLabels:
  environment: lab
  team: platform
EOF

# Install using values file
# -f specifies the values file to use
helm install nginx-custom bitnami/nginx \
  --namespace helm-lab \
  -f nginx-values.yaml
```

> **Values file best practice**: Only include values you're overriding. This makes it clear what's customized vs. using defaults. Store values files in Git for version control and change tracking.

### Verify Custom Configuration

```bash
# Should show 3 pods (replicaCount: 3)
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=nginx-custom

# Should show NodePort service on port 30080
kubectl get svc -n helm-lab nginx-custom

# Should show custom labels (environment: lab, team: platform)
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=nginx-custom --show-labels
```

> **What to verify**: Always confirm your customizations took effect. Check replica counts, service types, labels, and resource limits. This catches typos and misunderstandings early.

### Combining --set and Values File

```bash
# Values file provides base config, --set overrides specific values
# Here we override replicaCount from 3 (in file) to 1
# IMPORTANT: We also change the NodePort to avoid conflict with nginx-custom (which uses 30080)
helm install nginx-override bitnami/nginx \
  --namespace helm-lab \
  -f nginx-values.yaml \
  --set replicaCount=1 \
  --set service.nodePorts.http=30081
```

The `--set` flag takes precedence over values file.

> **⚠️ NodePort Conflict Warning**: If you install multiple releases using the same NodePort, Kubernetes will reject the installation with "provided port is already allocated". Always use different NodePorts for each release, or use `service.type=ClusterIP` to avoid port allocation entirely.

> **Use case for combining**: Use a values file for environment-specific defaults (staging.yaml, production.yaml), then use `--set` for deployment-specific tweaks without modifying the file.

### Cleanup Part 5

```bash
# Uninstall all three releases at once
helm uninstall custom-nginx nginx-custom nginx-override -n helm-lab
```

**📝 Key Learning**: Values files are the proper way to customize Helm charts for production. They're version-controllable, self-documenting, and make configurations reproducible across environments.

---

## Part 6: Upgrading and Rolling Back Releases

One of Helm's most powerful features is release management - tracking versions, upgrading safely, and rolling back if things go wrong.

### Install a Release for Upgrade Testing

```bash
# Install nginx with 2 replicas as our starting point
# This becomes revision 1
helm install upgrade-demo bitnami/nginx \
  --namespace helm-lab \
  --set replicaCount=2

# Wait for pods to be ready before proceeding
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=upgrade-demo -n helm-lab --timeout=120s
```

> **Why start here?** We're establishing a baseline (revision 1) that we can later roll back to if needed. In production, this would be your known-good state.

### View Release History

```bash
# Show the history of this release
# Each upgrade creates a new revision
helm history upgrade-demo -n helm-lab
```

> **What you'll see**: A table showing revision number, timestamp, status, chart version, and description. This is your audit trail for all changes.

### Upgrade the Release

```bash
# Upgrade with new values
# This creates revision 2
helm upgrade upgrade-demo bitnami/nginx \
  --namespace helm-lab \
  --set replicaCount=3 \
  --set resources.requests.memory=128Mi

# Watch the rolling update
# Kubernetes will gradually replace old pods with new ones
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=upgrade-demo --watch
```

Press `Ctrl+C` when complete.

> **What happens during upgrade**:
> 1. Helm renders templates with new values
> 2. Computes diff between current and desired state
> 3. Applies changes to the cluster
> 4. Kubernetes performs a rolling update (zero downtime)
> 5. Helm records the new revision

### View Updated History

```bash
# History now shows 2 revisions
helm history upgrade-demo -n helm-lab
```

You'll see revision 2 with status "deployed" and revision 1 with status "superseded".

### Perform Another Upgrade

```bash
# Upgrade again - this creates revision 3
helm upgrade upgrade-demo bitnami/nginx \
  --namespace helm-lab \
  --set replicaCount=4

# Check history - now shows 3 revisions
helm history upgrade-demo -n helm-lab
```

### Rollback to Previous Version

```bash
# Rollback to revision 2 (3 replicas)
# This is useful when the latest change (revision 3) caused problems
helm rollback upgrade-demo 2 -n helm-lab

# Verify rollback - history shows revision 4 (rollback creates new revision)
helm history upgrade-demo -n helm-lab

# Pods should scale back to 3
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=upgrade-demo
```

> **Rollback creates a new revision**: Notice revision 4 appeared - rollbacks are recorded as new revisions. This maintains a complete audit trail and allows you to "rollback the rollback" if needed.

### Rollback to First Version

```bash
# Rollback to revision 1 (original 2 replicas)
helm rollback upgrade-demo 1 -n helm-lab

# Verify - history shows all revisions including the new rollback
helm history upgrade-demo -n helm-lab
```

> **How far back can you go?** By default, Helm keeps the last 10 revisions. You can change this with `--history-max` flag during install/upgrade. In production, you might keep more for compliance.

### Cleanup Part 6

```bash
helm uninstall upgrade-demo -n helm-lab
```

**📝 Key Learning**: Helm's upgrade and rollback capabilities provide safe, auditable deployments. Every change is recorded, and you can instantly revert to any previous state. This is essential for production environments.

---

## Part 7: Generating Manifests Without Installing

Sometimes you need to see what a chart will create before actually deploying it. This is essential for code review, GitOps workflows, and debugging.

### Helm Template (Dry Run)

Use `helm template` to render charts locally without installing:

```bash
# Generate manifests without installing
# This renders all templates with your values but doesn't apply them
helm template test-nginx bitnami/nginx --namespace helm-lab > nginx-manifests.yaml

# View generated manifests
# You'll see all the Kubernetes resources the chart would create
head -100 nginx-manifests.yaml

# Count generated resources
# Useful to understand the chart's complexity
grep "^kind:" nginx-manifests.yaml | sort | uniq -c
```

> **Why use `helm template`**:
> - **Code review**: Review what will be deployed before deploying
> - **GitOps**: Generate manifests to commit to Git (for tools like ArgoCD)
> - **Debugging**: See exactly what templates produce with your values
> - **Learning**: Understand what a chart contains

### Dry Run with Server Validation

```bash
# Dry run that validates against the cluster
# Unlike 'helm template', this checks if resources are valid for YOUR cluster
helm install dry-run-test bitnami/nginx \
  --namespace helm-lab \
  --dry-run
```

> **Template vs Dry-run**: `helm template` is purely local - it doesn't contact the cluster. `--dry-run` connects to the cluster to validate that resources would be accepted (checks CRDs exist, RBAC is valid, etc.).

### Get Manifests from Installed Release

```bash
# First install something
helm install manifests-demo bitnami/nginx --namespace helm-lab

# Get the manifests that were applied
# This shows exactly what Helm sent to Kubernetes
helm get manifest manifests-demo -n helm-lab

# Get the values used
# Shows only the values that were overridden (not defaults)
helm get values manifests-demo -n helm-lab

# Get all release info
# Comprehensive dump of everything: manifest, values, hooks, notes
helm get all manifests-demo -n helm-lab

# Cleanup
helm uninstall manifests-demo -n helm-lab
```

> **Debugging production issues**: When something isn't working, `helm get manifest` shows you exactly what was deployed. Compare this against what you expected to find configuration problems.

**📝 Key Learning**: Always preview changes with `helm template` or `--dry-run` before deploying to production. Use `helm get` commands to inspect what's actually deployed when debugging issues.

---

## Part 8: Creating Your Own Helm Chart

Now we'll learn to create custom charts for your own applications. This is where Helm becomes a powerful tool for packaging and distributing your software.

### Create a New Chart

```bash
cd ~/helm-lab

# Create chart scaffolding
# Helm generates a complete, working chart structure
helm create myapp

# View the structure
# This shows all files and directories created
tree myapp || find myapp -type f
```

> **What `helm create` provides**: You get a fully functional chart that deploys NGINX. This is a great starting point - modify it for your application rather than starting from scratch.

### Chart Structure Explained

```
myapp/
├── Chart.yaml          # Chart metadata (name, version, description)
├── values.yaml         # Default configuration values
├── charts/             # Dependencies (subcharts)
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt       # Post-installation notes (displayed after install)
│   ├── _helpers.tpl    # Template helper functions (reusable snippets)
│   └── tests/
│       └── test-connection.yaml  # Helm test to verify deployment
└── .helmignore         # Files to ignore when packaging
```

> **Key files explained**:
> - **Chart.yaml**: Chart identity - name, version, dependencies
> - **values.yaml**: Default configuration - users override these
> - **templates/**: Go templates that render to Kubernetes manifests
> - **_helpers.tpl**: Reusable template functions (DRY principle)

### View Key Files

```bash
# View Chart.yaml - the chart's identity card
cat myapp/Chart.yaml

# View values.yaml - the configuration interface
cat myapp/values.yaml
```

### Understanding Templates

```bash
# View the deployment template
# Notice the {{ }} syntax - these are Go template directives
cat myapp/templates/deployment.yaml
```

Key template syntax:

| Syntax | Description | Example |
|--------|-------------|---------|
| `{{ .Values.xxx }}` | Access values.yaml | `{{ .Values.replicaCount }}` |
| `{{ .Release.Name }}` | Release name | `{{ .Release.Name }}-nginx` |
| `{{ .Chart.Name }}` | Chart name | `{{ .Chart.Name }}` |
| `{{ include "xxx" . }}` | Include helper template | `{{ include "myapp.fullname" . }}` |
| `{{- if .Values.xxx }}` | Conditional | `{{- if .Values.ingress.enabled }}` |
| `{{- range .Values.xxx }}` | Loop | `{{- range .Values.env }}` |

> **Template power**: These Go template directives let you create dynamic, configurable manifests. Users set values, templates render the appropriate Kubernetes resources.

### Modify the Chart

Let's simplify and customize the chart to understand how templates work:

```bash
# Update Chart.yaml - this defines chart metadata
cat > myapp/Chart.yaml <<'EOF'
apiVersion: v2
name: myapp
description: A simple web application chart for learning Helm
type: application
version: 0.1.0           # Chart version - increment when you change the chart
appVersion: "1.0.0"      # App version - the version of software being deployed
maintainers:
  - name: Lab User
    email: user@example.com
EOF
```

> **Version vs AppVersion**: `version` is the chart version (increment when templates change). `appVersion` is the application version being deployed (e.g., your software release).

```bash
# First, remove template files we don't need
# The default chart includes templates for features we won't use
# Removing them prevents "nil pointer" errors during linting
rm -f myapp/templates/ingress.yaml
rm -f myapp/templates/hpa.yaml
rm -f myapp/templates/httproute.yaml
rm -f myapp/templates/serviceaccount.yaml
rm -rf myapp/templates/tests

# Simplify NOTES.txt (the default one references removed templates)
cat > myapp/templates/NOTES.txt <<'EOF'
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To learn more about the release, try:
  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}
EOF

# Update values.yaml - the configuration interface for users
cat > myapp/values.yaml <<'EOF'
# Default values for myapp
# Users can override any of these in their own values file

replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "alpine"

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Application-specific config
# These values will be passed to the app via ConfigMap
app:
  name: "My Helm App"
  environment: "development"
  message: "Hello from Helm!"
EOF
```

> **Why remove templates?** The `helm create` command generates a full-featured chart with templates for Ingress, HPA, ServiceAccount, etc. These templates reference values we haven't defined. Removing unused templates keeps our chart simple and prevents linting errors.

> **Values file design**: Group related settings together. Use nested structures for complex configurations. Add comments to help users understand each option.

### Create a Custom ConfigMap Template

Now let's create a template that uses our custom values:

```bash
cat > myapp/templates/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  # Uses the fullname helper (defined in _helpers.tpl)
  # This ensures consistent naming across all resources
  name: {{ include "myapp.fullname" . }}-config
  labels:
    # Includes standard labels from helpers
    {{- include "myapp.labels" . | nindent 4 }}
data:
  # Values from values.yaml, quoted for safety
  # | quote ensures special characters are properly escaped
  APP_NAME: {{ .Values.app.name | quote }}
  ENVIRONMENT: {{ .Values.app.environment | quote }}
  MESSAGE: {{ .Values.app.message | quote }}
EOF
```

> **Template functions explained**:
> - `include "myapp.fullname" .` - Calls a helper function defined in _helpers.tpl
> - `| nindent 4` - Adds a newline and indents by 4 spaces (for YAML formatting)
> - `| quote` - Wraps the value in quotes (safe for special characters)

### Update Deployment to Use ConfigMap

```bash
cat > myapp/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          # Image is built from repository + tag values
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          # Load environment variables from our ConfigMap
          envFrom:
            - configMapRef:
                name: {{ include "myapp.fullname" . }}-config
          # Resources from values.yaml, converted to YAML
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
EOF
```

> **How templates connect**: Notice how the Deployment references the ConfigMap by name. Both use `{{ include "myapp.fullname" . }}` to ensure consistent naming. This pattern prevents resource naming conflicts.

### Validate the Chart

Before installing, always validate your chart:

```bash
# Lint the chart (check for errors)
# This catches syntax errors, missing required fields, etc.
helm lint myapp

# Render templates locally
# This shows exactly what Kubernetes resources would be created
helm template test-release myapp
```

> **Always lint before committing**: `helm lint` catches common errors like missing values references, incorrect indentation, and deprecated API versions. Run it as part of your CI/CD pipeline.

### Install Your Custom Chart

```bash
# Install from local directory (note the ./ prefix)
helm install my-release ./myapp --namespace helm-lab

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=my-release -n helm-lab --timeout=60s

# Check all resources created by our chart
kubectl get all -n helm-lab -l app.kubernetes.io/instance=my-release
kubectl get configmap -n helm-lab -l app.kubernetes.io/instance=my-release

# View ConfigMap - notice our values are rendered
kubectl get configmap my-release-myapp-config -n helm-lab -o yaml
```

> **What to verify**: Check that:
> - Pods are running (not CrashLoopBackOff)
> - ConfigMap contains expected values
> - Service exists and has correct ports

### Upgrade with Different Values

```bash
# Upgrade with production values
# This demonstrates how the same chart serves different environments
helm upgrade my-release ./myapp \
  --namespace helm-lab \
  --set app.environment=production \
  --set app.message="Hello from Production!" \
  --set replicaCount=2

# Verify changes in ConfigMap
kubectl get configmap my-release-myapp-config -n helm-lab -o yaml

# Verify 2 pods running
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=my-release
```

> **Same chart, different environments**: This is the power of Helm templates. One chart can deploy to development (1 replica, debug logging) or production (3 replicas, production config) just by changing values.

### Cleanup Part 8

```bash
helm uninstall my-release -n helm-lab
```

**📝 Key Learning**: Creating custom charts lets you package your applications for consistent, repeatable deployments. Templates provide flexibility while values files give users a clear configuration interface.

---

## Part 9: Packaging and Sharing Charts

Once you've created a chart, you'll want to share it with your team or the community. This section covers packaging and hosting charts.

### Package Your Chart

```bash
cd ~/helm-lab

# Package the chart into a distributable .tgz file
# This creates a versioned archive ready for distribution
helm package myapp

# View the package
# The filename includes the chart name and version
ls -la myapp-*.tgz
```

> **What's in the package**: The `.tgz` file contains all chart files (Chart.yaml, values.yaml, templates/) in a compressed archive. This is what gets uploaded to chart repositories.

### Install from Package

```bash
# Install from .tgz file (useful for offline/air-gapped environments)
helm install from-package ./myapp-0.1.0.tgz --namespace helm-lab

# Verify
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=from-package

# Cleanup
helm uninstall from-package -n helm-lab
```

> **Air-gapped deployments**: In secure environments without internet access, you can copy `.tgz` files and install directly. No repository access needed.

### Create a Chart Repository Index

```bash
# Create a repository directory
mkdir -p ~/helm-repo
cp myapp-0.1.0.tgz ~/helm-repo/

# Generate index file
# This creates index.yaml with metadata about all charts in the directory
helm repo index ~/helm-repo

# View index - this is what Helm clients download to discover charts
cat ~/helm-repo/index.yaml
```

> **Repository structure**: A Helm repository is just a web server hosting `.tgz` files and an `index.yaml`. It can be a simple HTTP server, GitHub Pages, S3 bucket, or dedicated solutions like ChartMuseum or Harbor.

### Serve the Repository Locally

```bash
# Start a simple HTTP server (in background)
# This simulates hosting your own chart repository
cd ~/helm-repo
python3 -m http.server 8888 &
HTTP_PID=$!
cd ~/helm-lab

# Add the local repository
# "local-repo" is the name you'll use to reference it
helm repo add local-repo http://localhost:8888

# Update and search
helm repo update
helm search repo local-repo
```

> **Production hosting options**:
> - **GitHub Pages**: Free, easy for public charts
> - **ChartMuseum**: Open-source chart repository server
> - **Harbor**: Enterprise registry with Helm support
> - **Cloud Storage**: S3, GCS, Azure Blob with proper CORS settings

### Install from Local Repository

```bash
# Install from local repo - same as any other repo!
helm install from-repo local-repo/myapp --namespace helm-lab

# Verify
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=from-repo

# Cleanup
helm uninstall from-repo -n helm-lab
helm repo remove local-repo
kill $HTTP_PID
```

**📝 Key Learning**: Helm charts can be packaged and hosted in repositories for team sharing. This enables a "chart as code" approach where applications are versioned, reviewed, and distributed like any other software package.

---

## Part 10: Real-World Chart Installation

Let's see Helm's power with a complex, real-world application - WordPress with its database. This demonstrates how charts handle multi-tier applications with dependencies.

### Install WordPress (Complex Application)

```bash
# Install WordPress with MariaDB database
# Notice how many configuration options we're setting
helm install my-wordpress bitnami/wordpress \
  --namespace helm-lab \
  --set wordpressUsername=admin \
  --set wordpressPassword=adminpassword \
  --set wordpressEmail=admin@example.com \
  --set service.type=ClusterIP \
  --set mariadb.primary.persistence.enabled=false \
  --set persistence.enabled=false \
  --set resources.requests.memory=256Mi \
  --set resources.requests.cpu=100m

# This will take a few minutes
echo "WordPress is deploying... this takes 2-3 minutes"
```

> **What's happening**: This single command deploys:
> - WordPress application container
> - MariaDB database container
> - Services for both components
> - Secrets for passwords
> - ConfigMaps for configuration
> 
> Without Helm, you'd need to create and coordinate all these YAML files manually.

### Watch Deployment Progress

```bash
# Watch pods - you'll see both WordPress and MariaDB pods
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=my-wordpress --watch
```

Press `Ctrl+C` when all pods are Running.

> **Deployment order**: The WordPress chart has dependencies configured. MariaDB starts first, then WordPress starts once the database is ready. Helm handles this coordination automatically.

### Access WordPress

```bash
# Port forward to test (runs in background)
kubectl port-forward -n helm-lab svc/my-wordpress 8080:80 &
sleep 3

# Test access - should get HTTP 200/302
curl -I http://localhost:8080

echo ""
echo "WordPress is available at http://localhost:8080"
echo "Login: admin / adminpassword"
```

> **Production note**: In production, you'd use Ingress instead of port-forward, enable persistence (so data survives restarts), and use Secrets management for credentials.

### View WordPress Resources

```bash
# See all resources created by the chart
echo "=== Pods ==="
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=my-wordpress

echo ""
echo "=== Services ==="
kubectl get svc -n helm-lab -l app.kubernetes.io/instance=my-wordpress

echo ""
echo "=== Secrets (credentials are stored here) ==="
kubectl get secrets -n helm-lab -l app.kubernetes.io/instance=my-wordpress

echo ""
echo "=== ConfigMaps ==="
kubectl get configmaps -n helm-lab -l app.kubernetes.io/instance=my-wordpress
```

> **Complexity hidden**: A production WordPress deployment requires coordination of multiple components. Helm charts encapsulate best practices and handle this complexity for you.

### Cleanup WordPress

```bash
# Stop port forward
pkill -f "port-forward.*my-wordpress"

# Uninstall WordPress - removes all resources created by the chart
helm uninstall my-wordpress -n helm-lab
```

**📝 Key Learning**: Helm charts can deploy complex multi-tier applications with a single command. The chart maintainers have encoded their expertise in configuration, dependencies, and best practices. You benefit from their experience without reading hundreds of lines of YAML.

---

## Scenario-Based Exercises: "CloudStore" E-Commerce Platform

You're the DevOps lead at **CloudStore Inc.**, tasked with deploying their microservices platform using Helm. The platform had reliability issues last quarter due to inconsistent deployments across environments. Your mission: standardize deployments using Helm.

> **Story Context**: CloudStore's developers were manually applying YAML files to deploy services. This led to configuration drift between environments, failed rollbacks, and long deployment times. The CTO has mandated using Helm for all deployments.

Each exercise combines concepts from previous parts to solve real deployment challenges.

```bash
# Setup workspace
cd ~/helm-lab
```

---

### Exercise 1: Deploy the Product Catalog Service

**Scenario**: Deploy the Product Catalog API, which is CloudStore's core service. The development team has been deploying it inconsistently - sometimes with 1 replica, sometimes with 3. You need to standardize this.

**Requirements**:
- 2 replicas for high availability
- Resource limits to prevent runaway containers
- Standard labels for filtering and monitoring

**What you'll learn**: How to use values files for consistent, repeatable deployments.

#### Step 1: Create the Values File

```bash
# Create values file for product catalog
# This becomes the source of truth for this service's configuration
# NOTE: We use Bitnami's default images (don't override image.repository/tag)
# to avoid image pull issues with Bitnami's chart dependencies
cat > product-catalog-values.yaml <<'EOF'
replicaCount: 2                    # Standard: 2 replicas for HA

service:
  type: ClusterIP                  # Internal service, not exposed externally
  port: 80

resources:
  requests:                        # Minimum resources guaranteed
    memory: "64Mi"
    cpu: "50m"
  limits:                          # Maximum resources allowed
    memory: "128Mi"
    cpu: "100m"

commonLabels:                      # Labels applied to all resources
  app: cloudstore
  component: product-catalog
  version: "1.0"
EOF
```

> **Why a values file instead of --set?** Values files are version-controllable, self-documenting, and reviewable. Commit this file to Git alongside your application code.

> **⚠️ Image Configuration Note**: Bitnami charts have init containers and dependencies that expect specific images. Overriding `image.repository` or `image.tag` can cause `ErrImagePull` errors. For production, use the chart's default images or ensure all dependent images are also updated.

#### Step 2: Deploy the Service

```bash
# Install using Bitnami nginx as base
helm install product-catalog bitnami/nginx \
  --namespace helm-lab \
  -f product-catalog-values.yaml
```

#### Step 3: Verify the Deployment

```bash
# Should show 2 pods (replicaCount: 2)
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=product-catalog

# Should show ClusterIP service (note: Bitnami adds "-nginx" suffix to service name)
kubectl get svc -n helm-lab -l app.kubernetes.io/instance=product-catalog
```

> **What to verify**: Pod count matches `replicaCount`, service type matches configuration, and labels are applied correctly. Note that Bitnami charts often add suffixes like `-nginx` to resource names.

**📝 Key Learning**: Values files provide consistent, auditable configuration. The same file deploys identical configurations every time, eliminating "works on my machine" problems.

---

### Exercise 2: Deploy Redis Cache

**Scenario**: CloudStore needs a Redis cache for session management and caching. Currently, each developer sets up Redis differently - some with persistence, some without, some with authentication, some without. This causes security and consistency issues.

**Requirements**:
- Standalone mode (not cluster - overkill for our use case)
- Authentication enabled (security requirement)
- No persistence (this is just a cache, not primary storage)

**What you'll learn**: How to configure complex applications through Helm values.

#### Step 1: Deploy Redis with Configuration

```bash
# Add Redis with specific configuration
# Notice how many aspects we're configuring with simple flags
helm install cloudstore-cache bitnami/redis \
  --namespace helm-lab \
  --set architecture=standalone \
  --set auth.password=cloudstore123 \
  --set master.persistence.enabled=false \
  --set master.resources.requests.memory=64Mi \
  --set master.resources.requests.cpu=50m
```

> **Configuration choices explained**:
> - `architecture=standalone`: Single Redis instance (simpler, sufficient for caching)
> - `auth.password`: Enables authentication (security best practice)
> - `persistence.enabled=false`: No disk storage (cache data can be regenerated)

#### Step 2: Wait for Redis to be Ready

```bash
# Wait for Redis pod to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cloudstore-cache -n helm-lab --timeout=120s
```

#### Step 3: Verify Redis is Working

```bash
# Test Redis connection
REDIS_POD=$(kubectl get pods -n helm-lab -l app.kubernetes.io/instance=cloudstore-cache -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n helm-lab $REDIS_POD -- redis-cli -a cloudstore123 ping
```

> **Expected output**: `PONG` - indicates Redis is running and authentication works.

**📝 Key Learning**: Helm charts for databases and infrastructure services expose configuration options that would otherwise require deep knowledge of the software. The chart maintainers have made secure, production-ready settings easy to apply.

---

### Exercise 3: Create Custom CloudStore Chart

**Scenario**: The CloudStore frontend needs a custom chart. The team wants to package their application configuration alongside the deployment manifests. This will enable self-service deployments where developers can deploy by simply providing a values file.

**Requirements**:
- Custom chart for CloudStore frontend
- Application configuration via ConfigMap
- Connection endpoints for backend services

**What you'll learn**: How to create charts that package application-specific configuration.

#### Step 1: Create the Chart Scaffold

```bash
# Create the chart
# Helm generates a working chart template we'll customize
helm create cloudstore-frontend
```

#### Step 2: Customize the Values

```bash
# Customize values.yaml with CloudStore-specific settings
cat > cloudstore-frontend/values.yaml <<'EOF'
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "alpine"

service:
  type: NodePort
  port: 80
  nodePort: 30090               # Fixed port for consistent access

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# CloudStore specific config
# These values get passed to the app via ConfigMap
cloudstore:
  siteName: "CloudStore"
  environment: "production"
  apiEndpoint: "http://product-catalog"
  cacheEndpoint: "cloudstore-cache-master:6379"
EOF
```

> **Custom values section**: The `cloudstore:` block shows how to add application-specific configuration. These values will be rendered into a ConfigMap that the application reads.

#### Step 3: Add a ConfigMap Template

```bash
# Add a ConfigMap template that uses our custom values
cat > cloudstore-frontend/templates/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "cloudstore-frontend.fullname" . }}-config
  labels:
    {{- include "cloudstore-frontend.labels" . | nindent 4 }}
data:
  SITE_NAME: {{ .Values.cloudstore.siteName | quote }}
  ENVIRONMENT: {{ .Values.cloudstore.environment | quote }}
  API_ENDPOINT: {{ .Values.cloudstore.apiEndpoint | quote }}
  CACHE_ENDPOINT: {{ .Values.cloudstore.cacheEndpoint | quote }}
EOF
```

> **Template connection**: The template uses `{{ .Values.cloudstore.xxx }}` to access the values we defined. The `| quote` filter ensures special characters are safely escaped.

#### Step 4: Install the Custom Chart

```bash
# Install the custom chart from local directory
helm install cloudstore-frontend ./cloudstore-frontend --namespace helm-lab

# Verify deployment
kubectl get all -n helm-lab -l app.kubernetes.io/instance=cloudstore-frontend

# Verify ConfigMap has our values
kubectl get configmap -n helm-lab cloudstore-frontend-config -o yaml
```

**📝 Key Learning**: Custom charts let you package application-specific configuration alongside deployment manifests. Developers can deploy by providing values without understanding Kubernetes internals.

---

### Exercise 4: Upgrade with Environment-Specific Values

**Scenario**: CloudStore needs to deploy to staging for QA testing, then promote to production. Each environment has different resource requirements and configuration. Instead of maintaining separate YAML files, we'll use environment-specific values files.

**Requirements**:
- Staging: 1 replica, staging-specific endpoints
- Production: 3 replicas, higher resources, production endpoints

**What you'll learn**: How to use values files for environment promotion without changing the chart.

#### Step 1: Create Environment-Specific Values Files

```bash
# Create staging values - minimal resources, staging identifiers
cat > cloudstore-staging.yaml <<'EOF'
replicaCount: 1                    # Single replica for staging

cloudstore:
  siteName: "CloudStore (STAGING)" # Visual indicator this is staging
  environment: "staging"
  apiEndpoint: "http://staging-api"
EOF

# Create production values - more resources, production config
cat > cloudstore-prod.yaml <<'EOF'
replicaCount: 3                    # Multiple replicas for HA

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

cloudstore:
  siteName: "CloudStore"
  environment: "production"
  apiEndpoint: "http://product-catalog"
EOF
```

> **Single chart, multiple environments**: The same chart serves both environments. Only the values change. This ensures staging and production use identical deployment logic.

#### Step 2: Deploy to Staging

```bash
# Upgrade to staging config
helm upgrade cloudstore-frontend ./cloudstore-frontend \
  --namespace helm-lab \
  -f cloudstore-staging.yaml

# Verify staging - should show 1 pod
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=cloudstore-frontend

# Verify ConfigMap has staging values
kubectl get configmap -n helm-lab cloudstore-frontend-config -o yaml | grep -E "SITE_NAME|ENVIRONMENT"
```

> **What to verify**: Pod count is 1, ConfigMap shows "STAGING" and "staging".

#### Step 3: Promote to Production

```bash
# Upgrade to production config
# Same chart, different values - this is the promotion process
helm upgrade cloudstore-frontend ./cloudstore-frontend \
  --namespace helm-lab \
  -f cloudstore-prod.yaml

# Verify production - should show 3 pods
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=cloudstore-frontend

# Check history - shows both staging and production deployments
helm history cloudstore-frontend -n helm-lab
```

> **Promotion workflow**: In a real CI/CD pipeline:
> 1. PR merged → Deploy to staging with `cloudstore-staging.yaml`
> 2. QA approved → Deploy to production with `cloudstore-prod.yaml`
> 3. Problem detected → Rollback with `helm rollback`

**📝 Key Learning**: Environment-specific values files enable consistent deployments across environments. The same chart, different values - promoting code is just changing which values file you use.

---

### Exercise 5: View Complete CloudStore Stack

**Scenario**: The operations team needs visibility into what's deployed. Create a status report showing all CloudStore components.

**What you'll learn**: How to use Helm commands for operational visibility.

#### View the Complete Platform

```bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║     CloudStore E-Commerce Platform Status              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo "📦 Helm Releases:"
helm list -n helm-lab

echo ""
echo "🚀 All Pods:"
kubectl get pods -n helm-lab

echo ""
echo "🌐 Services:"
kubectl get svc -n helm-lab

echo ""
echo "📊 Release History - Frontend:"
helm history cloudstore-frontend -n helm-lab
```

> **Operational visibility**: `helm list` shows all installed releases with their status, chart version, and app version. This is your deployment inventory - essential for tracking what's running in your cluster.

**📝 Key Learning**: Helm provides built-in operational visibility. `helm list` shows what's deployed, `helm history` shows the change log, and `helm status` shows current state. No need for external tracking spreadsheets!

---

### Cleanup Exercises

```bash
# Uninstall all CloudStore components
# Helm tracks what it created and removes everything cleanly
helm uninstall product-catalog cloudstore-cache cloudstore-frontend -n helm-lab

# Verify cleanup - should show no resources
kubectl get all -n helm-lab
```

> **Clean uninstall**: Helm removes all resources it created for each release. This is much safer than manually deleting resources - no risk of forgetting a ConfigMap or Secret.

---

## Key Takeaways

### Helm Basics

| Concept | What You Learned |
|---------|------------------|
| **Helm** | Package manager for Kubernetes - bundles manifests, provides templating, tracks releases |
| **Charts** | Packages containing templates, values, and metadata for deploying applications |
| **Releases** | Installed instances of charts - trackable, upgradable, rollbackable |
| **Values** | Configuration interface - customize charts without modifying them |

> **Key insight**: Helm separates "what to deploy" (the chart) from "how to configure it" (values). This enables reusable, customizable deployments.

### Working with Charts

| Task | Command | When to Use |
|------|---------|-------------|
| Find charts | `helm search repo <keyword>` | Discovering available charts |
| View options | `helm show values <chart>` | Before installing, to understand customization |
| Preview | `helm template <name> <chart>` | Code review, GitOps, debugging |
| Customize | `-f values.yaml` or `--set key=value` | Production deployments |

> **Key insight**: Always run `helm show values` before installing. This shows you the configuration interface for any chart.

### Managing Releases

| Operation | Command | Result |
|-----------|---------|--------|
| Install | `helm install` | Creates release revision 1 |
| Upgrade | `helm upgrade` | Creates new revision, rolls forward |
| Rollback | `helm rollback <revision>` | Creates new revision with old config |
| Uninstall | `helm uninstall` | Removes all release resources |

> **Key insight**: Every change creates a new revision. You can rollback to any previous state instantly. This is essential for production safety.

### Creating Charts

| Best Practice | Why It Matters |
|---------------|----------------|
| Use `helm create` | Generates working scaffold with best practices |
| Lint before commit | Catches errors early (`helm lint`) |
| Use helpers | DRY principle for naming, labels |
| Document values | Help users understand configuration options |

> **Key insight**: Well-designed charts make deployment self-service. Developers configure via values without needing to understand Kubernetes internals.

---

## Quick Reference

### Essential Commands

| Command | Description | When to Use |
|---------|-------------|-------------|
| `helm repo add <name> <url>` | Add a chart repository | First-time setup |
| `helm repo update` | Update repository cache | Before installing/upgrading |
| `helm search repo <keyword>` | Search for charts | Finding available charts |
| `helm show values <chart>` | Show default values | **Always before installing** |
| `helm install <release> <chart>` | Install a chart | New deployments |
| `helm install <release> <chart> -f values.yaml` | Install with values file | Production deployments |
| `helm install <release> <chart> --set key=value` | Install with inline values | Quick tests |
| `helm list` | List releases | See what's deployed |
| `helm status <release>` | Show release status | Check deployment health |
| `helm history <release>` | Show release history | Audit changes |
| `helm upgrade <release> <chart>` | Upgrade a release | Deploy changes |
| `helm rollback <release> <revision>` | Rollback to revision | Recover from bad deploy |
| `helm uninstall <release>` | Remove a release | Cleanup |
| `helm template <release> <chart>` | Render templates locally | Preview/GitOps |
| `helm lint <chart>` | Check chart for errors | Before committing |
| `helm create <name>` | Create new chart | New applications |
| `helm package <chart>` | Package chart to .tgz | Sharing/publishing |
| `helm get manifest <release>` | Get release manifests | Debugging |
| `helm get values <release>` | Get release values | Debugging |

### Common Flags

| Flag | Description | Example |
|------|-------------|---------|
| `-n, --namespace` | Kubernetes namespace | `-n production` |
| `-f, --values` | Specify values file | `-f values-prod.yaml` |
| `--set` | Set values on command line | `--set replicaCount=3` |
| `--dry-run` | Simulate installation | Preview what would be applied |
| `--wait` | Wait for resources to be ready | Block until deployment succeeds |
| `--timeout` | Time to wait for operation | `--timeout 5m` |
| `--create-namespace` | Create namespace if missing | Useful in CI/CD |
| `--atomic` | Rollback on failure | Production safety |
| `--debug` | Enable verbose output | Troubleshooting |

> **Production tip**: Use `--wait --atomic` together for safe deployments. If the deployment fails, Helm automatically rolls back to the previous version.

### Values File Template

Use this as a starting point for your own values files:

```yaml
# values.yaml
# Only include values you want to OVERRIDE from defaults
# This makes it clear what's customized

replicaCount: 2                    # Number of pods

image:
  repository: myapp                # Container image
  tag: "1.0.0"                     # Image tag (version)
  pullPolicy: IfNotPresent         # When to pull image

service:
  type: ClusterIP                  # ClusterIP, NodePort, or LoadBalancer
  port: 80                         # Service port

resources:
  limits:                          # Maximum resources
    cpu: 100m
    memory: 128Mi
  requests:                        # Guaranteed resources
    cpu: 50m
    memory: 64Mi

env:                               # Environment variables
  - name: APP_ENV
    value: production
```

> **Values file best practices**:
> - Only include values you're changing
> - Add comments explaining non-obvious choices
> - Use consistent naming with the chart's structure
> - Store in Git alongside application code

---

## Cleanup (End of Lab)

Clean up all resources created during the lab:

```bash
# List all releases to see what needs to be uninstalled
helm list -n helm-lab

# Uninstall all releases in helm-lab namespace
# xargs runs 'helm uninstall' for each release name
helm list -n helm-lab -q | xargs -r helm uninstall -n helm-lab

# Delete the namespace
# This removes any remaining resources not managed by Helm
kubectl delete namespace helm-lab

# Remove lab files from local filesystem
cd ~
rm -rf ~/helm-lab
rm -rf ~/helm-repo

# Verify cleanup
echo "=== Final Cleanup Verification ==="
echo "Helm releases (should be empty or not show helm-lab):"
helm list -A
echo ""
echo "Namespaces (should not show helm-lab):"
kubectl get namespaces | grep helm
```

> **Why clean up properly?** In KIND clusters, resources persist until explicitly deleted. Cleaning up frees cluster resources and prevents confusion in future labs.

---

## Troubleshooting Common Issues

This section covers the most common problems you'll encounter and how to diagnose them.

### Chart Not Found

**Symptom**: `Error: chart "xxx" not found` when trying to install.

**Cause**: Repository not added, not updated, or chart name is wrong.

```bash
# Update repositories - fetches latest chart index
helm repo update

# Search with debug - shows where Helm is looking
helm search repo <name> --debug

# Check repo is added
helm repo list

# Verify exact chart name (names are case-sensitive!)
helm search repo <partial-name>
```

> **Common fixes**: Run `helm repo update` first. Check exact chart name with `helm search repo`. Ensure you've added the repository containing the chart.

### Installation Fails

**Symptom**: `helm install` errors out with YAML parse errors or Kubernetes API errors.

**Cause**: Template rendering issues, invalid values, or cluster problems.

```bash
# Use --debug for detailed error information
helm install <release> <chart> --debug

# Check Kubernetes events for scheduling/resource issues
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check pod logs if pods are crashing
kubectl logs -n <namespace> <pod-name>

# Check pod description for error messages
kubectl describe pod -n <namespace> <pod-name>
```

> **Debugging strategy**: 
> 1. Run with `--debug` to see template output
> 2. Check if it's a Helm issue (template rendering) or Kubernetes issue (deployment)
> 3. For Kubernetes issues, check events and pod logs

### NodePort Already Allocated

**Symptom**: `Service "xxx" is invalid: spec.ports[0].nodePort: Invalid value: provided port is already allocated`

**Cause**: Another service is already using the same NodePort.

```bash
# Find which service is using the port
kubectl get svc -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.ports[*].nodePort}{"\n"}{end}' | grep <port>

# Either use a different NodePort or change to ClusterIP
helm install <release> <chart> --set service.type=ClusterIP
# OR
helm install <release> <chart> --set service.nodePorts.http=30081  # different port
```

> **Best practice**: Use ClusterIP for internal services and only use NodePort when you specifically need external access. This avoids port conflicts entirely.

### Bitnami Image Pull Errors

**Symptom**: Pods stuck in `Init:ErrImagePull` or `ErrImagePull` state when using Bitnami charts.

**Cause**: Bitnami charts have init containers that require specific image versions. Overriding image repository/tag can break dependencies.

```bash
# Check which images are failing
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Events:"

# Check the full image pull error
kubectl get events -n <namespace> --field-selector reason=Failed
```

**Solutions**:

1. **Don't override images** - Use the chart's default images:
```bash
# BAD: May cause image pull errors
helm install myapp bitnami/nginx --set image.repository=nginx --set image.tag=alpine

# GOOD: Use defaults
helm install myapp bitnami/nginx
```

2. **If you must use custom images**, ensure all related images are overridden:
```bash
# Check all image values in the chart
helm show values bitnami/nginx | grep -i image
```

> **Since August 2025**: Bitnami changed their licensing model. Some images require subscriptions. For learning purposes, using default images works fine. In production, review Bitnami's licensing terms.

### Upgrade Fails

**Symptom**: `helm upgrade` fails with conflict or validation errors.

**Cause**: Incompatible changes, missing required values, or chart version issues.

```bash
# Check current release status and what's deployed
helm status <release> -n <namespace>

# Get manifest to see current state
helm get manifest <release> -n <namespace>

# Get values currently applied
helm get values <release> -n <namespace>

# Force upgrade (use with caution - can cause downtime)
helm upgrade <release> <chart> --force
```

> **When to use --force**: Only when Helm's diff is incorrect or resources need to be deleted/recreated. This can cause downtime - prefer normal upgrades.

### Rollback Issues

**Symptom**: `helm rollback` doesn't restore expected state.

**Cause**: Revision doesn't exist, or values have external dependencies.

```bash
# Check revision history - find the revision you want
helm history <release> -n <namespace>

# Get values from specific revision - verify what will be restored
helm get values <release> -n <namespace> --revision <number>

# Rollback with debug output
helm rollback <release> <revision> -n <namespace> --debug
```

> **Rollback gotchas**: 
> - Rollback creates a NEW revision (not truly "going back")
> - External changes (manual kubectl edits) won't be rolled back
> - Database migrations can't be automatically reversed

### Template Errors

**Symptom**: Helm reports template parsing or rendering errors.

**Cause**: Syntax errors in templates, missing values, or incorrect YAML formatting.

```bash
# Lint the chart - catches common errors
helm lint <chart-path>

# Render templates to see errors with full debug output
helm template test <chart-path> --debug

# Test with specific values to isolate problems
helm template test <chart-path> --set key=value

# Render just one template (if you know which is problematic)
helm template test <chart-path> --show-only templates/deployment.yaml
```

> **Common template errors**:
> - Missing `{{ }}` closing braces
> - Wrong indentation (use `nindent` carefully)
> - Accessing non-existent values (add `default` or `if` checks)

### Values Not Applied

**Symptom**: Release deployed but configuration is wrong - values seem ignored.

**Cause**: Values file not used, wrong key names, or precedence issues.

```bash
# Check actual values used in the release
helm get values <release> -n <namespace>

# Compare with chart defaults
helm show values <chart>

# Use --dry-run to verify before applying
helm upgrade <release> <chart> -f values.yaml --dry-run

# Check for typos - keys are case-sensitive!
cat values.yaml
```

> **Common causes**:
> - Typo in key name (YAML keys are case-sensitive)
> - Values file not specified with `-f`
> - `--set` overriding your values file
> - Nested structure doesn't match chart expectations

---

## Additional Resources

### Official Documentation
- [Helm Documentation](https://helm.sh/docs/) - Complete reference for all Helm features
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/) - How to write production-quality charts
- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/) - Deep dive into Go templating

### Finding Charts
- [Artifact Hub](https://artifacthub.io/) - The primary registry for finding Helm charts
- [Bitnami Charts](https://github.com/bitnami/charts) - Well-maintained charts for common applications

### Advanced Topics
- [Helm Hooks](https://helm.sh/docs/topics/charts_hooks/) - Run jobs during install/upgrade lifecycle
- [Chart Dependencies](https://helm.sh/docs/helm/helm_dependency/) - Managing subcharts
- [OCI Registry Support](https://helm.sh/docs/topics/registries/) - Storing charts in container registries

> **Next steps**: After completing this lab, explore Helm hooks for database migrations, chart dependencies for microservices, and consider how Helm fits into your CI/CD pipeline with tools like ArgoCD or Flux.
