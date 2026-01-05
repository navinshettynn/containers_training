# Container Registries – Hands-on Lab (Play with Docker)

This lab is designed to be shared with participants. It includes **commands**, **explanations**, and **special notes** specific to **Play with Docker (PWD)**.

---

## Important: How to Use Play with Docker (PWD)

1. Open `https://labs.play-with-docker.com`
2. Login using Docker Hub or GitHub
3. Click **Add New Instance**
4. You will get a terminal with Docker available

### Copy-Paste Tip (PWD)

Play with Docker does **not** always handle normal paste reliably.

- **Use:** `Ctrl + Shift + V` (recommended)
- **Avoid relying on:** `Ctrl + V`

Some commands below are formatted to copy/paste cleanly; if something looks correct but fails, retry with `Ctrl + Shift + V`.

---

## Learning Objectives

- Understand what **container registries** are and why they matter
- Work with **Docker Hub** as the default public registry
- Understand **image naming conventions** (registry, repository, tag, digest)
- **Pull** images from registries
- **Push** images to Docker Hub
- **Search** for images and explore repositories
- Authenticate with registries using **docker login**

### Intermediate Objectives (Optional)

- Run a **private registry** locally
- Configure registry **authentication and TLS**
- Implement **image tagging strategies** for CI/CD
- Use **registry mirrors** and caching proxies
- Work with **multi-architecture images**
- Manage registry **storage and garbage collection**
- Explore alternative registries (GitHub, GitLab, AWS ECR, etc.)

### Tip: Use a Name Prefix

On shared hosts or busy workstations, prefix image names (e.g., `lab-myapp`) so you don't clash with existing resources.

---

## Quick Sanity Check

Verify Docker is installed and can communicate with registries:

```bash
docker version
docker info | grep -i registry
```

You should see `Registry: https://index.docker.io/v1/` as the default.

---

## Part 1: Understanding Container Registries

A **container registry** is a storage and distribution system for container images. Think of it like GitHub, but for Docker images instead of code.

### Key Concepts

| Term | Description |
|------|-------------|
| **Registry** | Server that stores and distributes images (e.g., Docker Hub, gcr.io) |
| **Repository** | Collection of related images (e.g., `nginx`, `mycompany/webapp`) |
| **Tag** | Version label for an image (e.g., `latest`, `1.0`, `alpine`) |
| **Digest** | Immutable SHA256 hash identifying an exact image |

### Image Name Anatomy

```
[registry/][namespace/]repository[:tag|@digest]
```

Examples:

| Full Name | Registry | Namespace | Repository | Tag |
|-----------|----------|-----------|------------|-----|
| `nginx` | docker.io | library | nginx | latest |
| `nginx:1.25-alpine` | docker.io | library | nginx | 1.25-alpine |
| `myuser/myapp:v1` | docker.io | myuser | myapp | v1 |
| `gcr.io/google-containers/pause:3.9` | gcr.io | google-containers | pause | 3.9 |
| `localhost:5000/myapp:dev` | localhost:5000 | (none) | myapp | dev |

### Note

When you omit the registry, Docker assumes `docker.io` (Docker Hub). When you omit the tag, Docker assumes `latest`.

---

## Part 2: Docker Hub – The Default Registry

Docker Hub is the world's largest container registry with millions of public images.

### Search for Images (CLI)

```bash
docker search nginx
```

Output shows:

```
NAME                    DESCRIPTION                                     STARS     OFFICIAL
nginx                   Official build of Nginx.                        19000     [OK]
nginx/nginx-ingress     NGINX and NGINX Plus Ingress Controllers...    100
linuxserver/nginx       An Nginx container...                          200
...
```

| Column | Meaning |
|--------|---------|
| NAME | Repository name |
| DESCRIPTION | Brief description |
| STARS | Popularity indicator |
| OFFICIAL | Maintained by Docker or the software vendor |

### Limit Search Results

```bash
docker search --limit 5 nginx
```

### Filter by Stars

```bash
docker search --filter stars=100 nginx
```

### Search Official Images Only

```bash
docker search --filter is-official=true database
```

### Note

The CLI search is limited. For full features (Dockerfile, README, tags), visit https://hub.docker.com

---

## Part 3: Pulling Images from Registries

### Pull the Latest Nginx Image

```bash
docker image pull nginx
```

This is equivalent to:

```bash
docker image pull docker.io/library/nginx:latest
```

### Pull a Specific Tag

```bash
docker image pull nginx:1.25-alpine
```

### Pull from a Different Registry

```bash
docker image pull gcr.io/google-containers/pause:3.9
```

### Pull by Digest (Immutable Reference)

```bash
docker image pull nginx@sha256:6926dd802f40e5e7257fded83e0d8030039642e4e10c4a98a6478e9c6f0a4e6f
```

Digests are useful when you need to guarantee the exact same image every time.

### View Pull Progress

When pulling, Docker shows layer download progress:

```
1.25-alpine: Pulling from library/nginx
4abcf2066143: Pull complete
b4df32aa5a72: Pull complete
...
Digest: sha256:abc123...
Status: Downloaded newer image for nginx:1.25-alpine
```

### List Downloaded Images

```bash
docker image ls
```

---

## Part 4: Image Tags and Versioning

Tags help organize and version images. Understanding tagging conventions is crucial.

### Common Tagging Patterns

| Pattern | Example | Use Case |
|---------|---------|----------|
| Semantic Version | `1.25.3` | Production, pinned version |
| Major.Minor | `1.25` | Floating patch updates |
| Major | `1` | Floating minor updates |
| `latest` | `latest` | Development, most recent build |
| Base Image | `alpine`, `slim` | Variant indicator |
| Combined | `1.25-alpine` | Version + variant |
| Git SHA | `abc1234` | CI/CD builds |
| Date | `2024-01-15` | Nightly builds |

### Pull Different Tags of the Same Image

```bash
docker image pull alpine:3.18
docker image pull alpine:3.19
docker image pull alpine:edge
```

### Compare Image Sizes

```bash
docker image ls alpine
```

```
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
alpine       3.19      ace17d5d883e   2 weeks ago    7.73MB
alpine       3.18      c1aabb73d233   2 weeks ago    7.33MB
alpine       edge      abc123...      1 week ago     8.02MB
```

### The `latest` Tag Warning

`latest` is just a convention—it doesn't guarantee the newest version:

- It may not be updated by maintainers
- It's mutable (can point to different images over time)
- **Avoid using `latest` in production**

### Verify an Image Tag Exists

```bash
docker manifest inspect nginx:1.25-alpine
```

This checks if the tag exists without downloading the image.

---

## Part 5: Authenticating with Docker Hub

To push images, you need to authenticate.

### Login to Docker Hub

```bash
docker login
```

Enter your Docker Hub username and password when prompted:

```
Login with your Docker ID to push and pull images from Docker Hub.
Username: your-username
Password:
Login Succeeded
```

### Login Non-Interactively (CI/CD)

```bash
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
```

### Check Login Status

```bash
cat ~/.docker/config.json
```

This file stores your authentication credentials (encoded, not encrypted).

### Logout

```bash
docker logout
```

### Login to Other Registries

```bash
# GitHub Container Registry
docker login ghcr.io

# Google Container Registry
docker login gcr.io

# Amazon ECR (requires AWS CLI)
aws ecr get-login-password | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

---

## Part 6: Pushing Images to Docker Hub

### Create a Simple Image

```bash
mkdir -p ~/lab/registry && cd ~/lab/registry

cat > Dockerfile <<'EOF'
FROM alpine
RUN apk add --no-cache curl
CMD ["curl", "--version"]
EOF

docker image build -t mycurl .
```

### Tag for Your Docker Hub Account

Replace `<your-username>` with your actual Docker Hub username:

```bash
docker image tag mycurl <your-username>/mycurl:1.0
docker image tag mycurl <your-username>/mycurl:latest
```

### Verify the Tags

```bash
docker image ls | grep mycurl
```

```
mycurl                        latest    abc123...   1 minute ago    12MB
<your-username>/mycurl        1.0       abc123...   1 minute ago    12MB
<your-username>/mycurl        latest    abc123...   1 minute ago    12MB
```

### Push to Docker Hub

```bash
docker image push <your-username>/mycurl:1.0
docker image push <your-username>/mycurl:latest
```

Output:

```
The push refers to repository [docker.io/<your-username>/mycurl]
abc123: Pushed
def456: Mounted from library/alpine
1.0: digest: sha256:... size: 1234
```

### Push All Tags at Once

```bash
docker image push --all-tags <your-username>/mycurl
```

### Verify on Docker Hub

Visit `https://hub.docker.com/r/<your-username>/mycurl` to see your repository.

---

## Part 7: Working with Image Digests

Digests provide immutable references to specific image versions.

### Get an Image's Digest

```bash
docker image inspect nginx:alpine --format '{{index .RepoDigests 0}}'
```

Output:

```
nginx@sha256:6a2f8b28e45c4adea04ec207a251fd4a2df03ddc930f782af51e315ebc76e9a9
```

### Pull by Digest

```bash
docker image pull nginx@sha256:6a2f8b28e45c4adea04ec207a251fd4a2df03ddc930f782af51e315ebc76e9a9
```

### Why Use Digests?

| Tags | Digests |
|------|---------|
| Mutable (can change) | Immutable (fixed forever) |
| Human-friendly | Machine-friendly |
| Good for development | Required for security/compliance |

### Best Practice

In production deployments, pin images by digest:

```yaml
# docker-compose.yml or Kubernetes manifest
image: nginx@sha256:6a2f8b28e45c4adea04ec207a251fd4a2df03ddc930f782af51e315ebc76e9a9
```

---

## Exercises

### Exercise 1: Explore Docker Hub

1. Search for official Python images
2. Pull three different variants (slim, alpine, full)
3. Compare their sizes

```bash
docker search --filter is-official=true python

docker image pull python:3.12
docker image pull python:3.12-slim
docker image pull python:3.12-alpine

docker image ls python
```

### Exercise 2: Tag and Push an Image

1. Create a simple image (or use one from earlier labs)
2. Tag it with multiple versions (1.0, 1.0.0, latest)
3. Push all tags to Docker Hub

```bash
docker image pull alpine
docker image tag alpine <your-username>/myalpine:1.0
docker image tag alpine <your-username>/myalpine:1.0.0
docker image tag alpine <your-username>/myalpine:latest

docker login
docker image push --all-tags <your-username>/myalpine
```

### Exercise 3: Work with Digests

1. Pull an image by tag
2. Find its digest
3. Remove the image locally
4. Pull again using only the digest

```bash
docker image pull nginx:alpine
docker image inspect nginx:alpine --format '{{index .RepoDigests 0}}'
# Copy the digest

docker image rm nginx:alpine
docker image pull nginx@sha256:<paste-digest-here>
```

---

## Optional Advanced Exercises (Intermediate)

> **Context:** You're the DevOps engineer for a company that's outgrown Docker Hub's free tier. Builds are slow due to rate limits, and security requires keeping images in-house. Your job: set up proper registry infrastructure.

---

## Part 8 (Optional): Running a Private Registry

Docker Hub has rate limits and your CI/CD pipeline is getting throttled. You need a local registry for faster, unlimited pulls.

### Start a Local Registry

```bash
docker container run -d -p 5000:5000 --name registry registry:2
```

### Verify It's Running

```bash
curl http://localhost:5000/v2/_catalog
```

Output: `{"repositories":[]}`

### Push an Image to Your Registry

```bash
# Tag an existing image for the local registry
docker image tag alpine localhost:5000/myalpine:1.0

# Push to local registry
docker image push localhost:5000/myalpine:1.0
```

### Verify the Image Is Stored

```bash
curl http://localhost:5000/v2/_catalog
```

Output: `{"repositories":["myalpine"]}`

### List Tags for a Repository

```bash
curl http://localhost:5000/v2/myalpine/tags/list
```

Output: `{"name":"myalpine","tags":["1.0"]}`

### Pull from Your Registry

```bash
# Remove local copy
docker image rm localhost:5000/myalpine:1.0

# Pull from registry
docker image pull localhost:5000/myalpine:1.0
```

### Cleanup

```bash
docker container rm -f registry
```

---

## Part 9 (Optional): Registry with Persistent Storage

Your registry container crashed and all images were lost. You need persistent storage.

### Create a Volume for Registry Data

```bash
docker volume create registry-data
```

### Run Registry with Persistent Storage

```bash
docker container run -d \
  -p 5000:5000 \
  --name registry \
  -v registry-data:/var/lib/registry \
  registry:2
```

### Push Some Images

```bash
docker image tag nginx:alpine localhost:5000/nginx:alpine
docker image push localhost:5000/nginx:alpine
```

### Simulate a Crash

```bash
docker container rm -f registry
```

### Restart Registry

```bash
docker container run -d \
  -p 5000:5000 \
  --name registry \
  -v registry-data:/var/lib/registry \
  registry:2
```

### Verify Images Survived

```bash
curl http://localhost:5000/v2/_catalog
```

The images are still there because they're stored in the volume.

### Cleanup

```bash
docker container rm -f registry
docker volume rm registry-data
```

---

## Part 10 (Optional): Securing Your Registry with TLS

Your security team flagged that the registry uses plain HTTP. You need HTTPS.

### Generate Self-Signed Certificates

```bash
mkdir -p ~/lab/certs && cd ~/lab/certs

openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout domain.key -x509 -days 365 \
  -out domain.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
```

### Run Registry with TLS

```bash
docker container run -d \
  -p 5000:5000 \
  --name secure-registry \
  -v ~/lab/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  registry:2
```

### Test HTTPS Access

```bash
curl -k https://localhost:5000/v2/_catalog
```

The `-k` flag tells curl to accept self-signed certificates.

### Configure Docker to Trust the Certificate

For production, you would add the certificate to Docker's trust store:

```bash
# On Linux
sudo mkdir -p /etc/docker/certs.d/localhost:5000
sudo cp ~/lab/certs/domain.crt /etc/docker/certs.d/localhost:5000/ca.crt

# Restart Docker
sudo systemctl restart docker
```

### Cleanup

```bash
docker container rm -f secure-registry
rm -rf ~/lab/certs
```

---

## Part 11 (Optional): Registry with Authentication

Unauthorized users are pushing images to your registry. You need password protection.

### Create a Password File

```bash
mkdir -p ~/lab/auth && cd ~/lab/auth

docker container run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn admin secretpassword > htpasswd

cat htpasswd
```

### Run Registry with Basic Auth

```bash
docker container run -d \
  -p 5000:5000 \
  --name auth-registry \
  -v ~/lab/auth:/auth \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2
```

### Try to Access Without Auth (Fails)

```bash
curl http://localhost:5000/v2/_catalog
```

Output: `{"errors":[{"code":"UNAUTHORIZED"...}]}`

### Login to Your Registry

```bash
docker login localhost:5000
# Username: admin
# Password: secretpassword
```

### Push an Image (Works Now)

```bash
docker image tag alpine localhost:5000/alpine:latest
docker image push localhost:5000/alpine:latest
```

### Verify

```bash
curl -u admin:secretpassword http://localhost:5000/v2/_catalog
```

### Cleanup

```bash
docker container rm -f auth-registry
docker logout localhost:5000
rm -rf ~/lab/auth
```

---

## Part 12 (Optional): Registry Garbage Collection

Your registry is consuming too much disk space. Old, untagged layers are piling up.

### Understand the Problem

When you delete a tag, the underlying layers remain until garbage collection runs.

### Set Up a Test Registry

```bash
docker volume create gc-test
docker container run -d \
  -p 5000:5000 \
  --name gc-registry \
  -v gc-test:/var/lib/registry \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2
```

### Push and Delete Images

```bash
# Push an image
docker image tag alpine localhost:5000/test:1
docker image push localhost:5000/test:1

# Delete the tag via API
curl -X DELETE http://localhost:5000/v2/test/manifests/$(
  curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    http://localhost:5000/v2/test/manifests/1 | grep Docker-Content-Digest | awk '{print $2}' | tr -d '\r'
)
```

### Run Garbage Collection

```bash
docker container exec gc-registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

### Dry Run First

```bash
docker container exec gc-registry bin/registry garbage-collect --dry-run /etc/docker/registry/config.yml
```

This shows what would be deleted without actually deleting.

### Cleanup

```bash
docker container rm -f gc-registry
docker volume rm gc-test
```

---

## Part 13 (Optional): Registry Mirroring (Pull-Through Cache)

Your team pulls the same base images hundreds of times a day. You want to cache them locally to save bandwidth and avoid rate limits.

### Run a Pull-Through Cache

```bash
docker container run -d \
  -p 5000:5000 \
  --name mirror \
  -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
  registry:2
```

### Configure Docker to Use the Mirror

Create or edit `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["http://localhost:5000"]
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### Test the Cache

```bash
# First pull goes to Docker Hub (and caches)
docker image pull nginx:alpine

# Subsequent pulls come from cache
docker image rm nginx:alpine
docker image pull nginx:alpine
```

The second pull is faster and doesn't count against Docker Hub rate limits.

### View Cached Images

```bash
curl http://localhost:5000/v2/_catalog
```

### Cleanup

```bash
docker container rm -f mirror
# Remember to remove the registry-mirrors from daemon.json
```

---

## Part 14 (Optional): Multi-Architecture Images

Your team develops on M1 Macs (ARM) but deploys to x86 servers. You need images that work on both.

### Check an Image's Architectures

```bash
docker manifest inspect nginx:alpine
```

Look for the `platform` field showing different `architecture` values (amd64, arm64, etc.).

### Inspect Specific Architecture

```bash
docker manifest inspect --verbose nginx:alpine | jq '.[].Descriptor.platform'
```

### Build Multi-Architecture Images

First, create a builder:

```bash
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```

### Build and Push Multi-Arch Image

```bash
mkdir -p ~/lab/multiarch && cd ~/lab/multiarch

cat > Dockerfile <<'EOF'
FROM alpine
RUN uname -m > /arch.txt
CMD cat /arch.txt
EOF

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t <your-username>/multiarch:1.0 \
  --push \
  .
```

### Verify

```bash
docker manifest inspect <your-username>/multiarch:1.0
```

You should see both `amd64` and `arm64` architectures.

### Cleanup

```bash
docker buildx rm multiarch
rm -rf ~/lab/multiarch
```

---

## Part 15 (Optional): Alternative Registries

Docker Hub isn't the only option. Here's how to work with other popular registries.

### GitHub Container Registry (ghcr.io)

```bash
# Login with GitHub Personal Access Token
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Tag and push
docker image tag myapp ghcr.io/<github-username>/myapp:1.0
docker image push ghcr.io/<github-username>/myapp:1.0
```

### GitLab Container Registry

```bash
# Login
docker login registry.gitlab.com -u <gitlab-username> -p <access-token>

# Tag and push
docker image tag myapp registry.gitlab.com/<group>/<project>/myapp:1.0
docker image push registry.gitlab.com/<group>/<project>/myapp:1.0
```

### Amazon ECR

```bash
# Login (requires AWS CLI configured)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Create repository (one-time)
aws ecr create-repository --repository-name myapp

# Tag and push
docker image tag myapp <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0
docker image push <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0
```

### Google Container Registry (gcr.io)

```bash
# Login (requires gcloud configured)
gcloud auth configure-docker

# Tag and push
docker image tag myapp gcr.io/<project-id>/myapp:1.0
docker image push gcr.io/<project-id>/myapp:1.0
```

### Azure Container Registry

```bash
# Login
az acr login --name <registry-name>

# Tag and push
docker image tag myapp <registry-name>.azurecr.io/myapp:1.0
docker image push <registry-name>.azurecr.io/myapp:1.0
```

---

## Key Takeaways

- **Container registries** store and distribute Docker images
- **Docker Hub** is the default registry with millions of public images
- Image names follow the pattern: `[registry/][namespace/]repository[:tag]`
- **Tags** are mutable; **digests** are immutable—use digests for production
- Use `docker login` to authenticate before pushing
- **Private registries** provide control, speed, and avoid rate limits
- Secure registries with **TLS** and **authentication**
- Use **pull-through caches** to reduce bandwidth and rate limit impact
- Choose registries based on your infrastructure (AWS → ECR, GCP → GCR, etc.)

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `docker search NAME` | Search Docker Hub for images |
| `docker image pull NAME[:TAG]` | Pull image from registry |
| `docker image push NAME[:TAG]` | Push image to registry |
| `docker image push --all-tags NAME` | Push all tags of an image |
| `docker login [REGISTRY]` | Authenticate with a registry |
| `docker logout [REGISTRY]` | Remove stored credentials |
| `docker image tag SRC DST` | Create a new tag for an image |
| `docker manifest inspect NAME` | View image manifest (multi-arch info) |
| `docker image inspect --format '{{.RepoDigests}}' NAME` | Get image digest |
| `docker buildx build --platform PLATFORMS` | Build multi-architecture image |

---

## Cleanup (End of Lab)

```bash
# Remove containers
docker container rm -f registry secure-registry auth-registry gc-registry mirror 2>/dev/null || true

# Remove lab images
docker image rm mycurl localhost:5000/myalpine:1.0 localhost:5000/nginx:alpine 2>/dev/null || true
docker image rm localhost:5000/alpine:latest localhost:5000/test:1 2>/dev/null || true

# Remove volumes
docker volume rm registry-data gc-test 2>/dev/null || true

# Remove lab directories
rm -rf ~/lab/registry ~/lab/certs ~/lab/auth ~/lab/multiarch

# Logout from registries
docker logout 2>/dev/null || true
docker logout localhost:5000 2>/dev/null || true
docker logout ghcr.io 2>/dev/null || true

# Remove buildx builder (if created)
docker buildx rm multiarch 2>/dev/null || true
```


