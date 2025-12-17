# Docker Images – Hands-on Lab (Play with Docker)

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

- Understand the **three ways** to create Docker images
- Create images **interactively** using `docker container commit`
- Write and understand **Dockerfiles**
- **Build** images using `docker image build`
- **Tag** images for versioning and registry compatibility
- **Save** and **load** images for offline transfer
- **Push** images to Docker Hub

### Intermediate Objectives (Optional)

- Use **multi-stage builds** to create smaller production images
- Understand **build context** and `.dockerignore`
- Leverage **layer caching** for faster builds
- Use **build arguments (ARG)** for flexible builds
- Add **metadata** to images with LABEL
- Inspect images and understand layer composition

### Tip: Use a Name Prefix

On shared hosts or busy workstations, prefix image names (e.g., `lab-myapp`, `lab-web`) so you don't clash with existing resources.

---

## Quick Sanity Check

Verify Docker is installed and can pull images:

```bash
docker version
docker image ls
```

---

## Part 1: Understanding Docker Images

A Docker image is a read-only template used to create containers. Images are made up of **layers**, where each layer represents a set of filesystem changes.

### Three Ways to Create Images

| Method | Description | Use Case |
|--------|-------------|----------|
| **Interactive (commit)** | Modify a running container, then save changes | Quick experiments, learning |
| **Dockerfile** | Declarative file describing the image | Production, CI/CD, reproducible builds |
| **Import from tarball** | Load an exported image file | Offline transfer, backups |

We'll explore each method in this lab.

---

## Part 2: Interactive Image Creation

The simplest way to understand images is to create one interactively. We'll start a container, make changes, and commit those changes to a new image.

### Start an Interactive Container

```bash
docker container run -it --name sample alpine /bin/sh
```

You should see a prompt like `/ #`. You are now inside an Alpine Linux container.

### Install a Package

By default, Alpine doesn't have `ping` installed. Let's add it:

```sh
apk update && apk add iputils
```

### Verify the Installation

```sh
ping -c 2 127.0.0.1
```

You should see ping responses.

### Exit the Container

```sh
exit
```

### View Container Changes

The container has exited but still exists. Let's see what changed:

```bash
docker container ls -a | grep sample
```

Now view the filesystem changes:

```bash
docker container diff sample
```

**Output legend:**

| Symbol | Meaning |
|--------|---------|
| `A` | Added |
| `C` | Changed |
| `D` | Deleted |

You'll see files added for the `iputils` package.

### Commit the Container to a New Image

```bash
docker container commit sample my-alpine
```

This creates a new image called `my-alpine` from the container's current state.

### Verify the New Image

```bash
docker image ls | grep my-alpine
```

You should see:

```
REPOSITORY   TAG      IMAGE ID       CREATED          SIZE
my-alpine    latest   44bca4141130   10 seconds ago   8.5MB
```

### View Image History

```bash
docker image history my-alpine
```

This shows all the layers that make up your image.

### Test the New Image

```bash
docker container run --rm my-alpine ping -c 2 127.0.0.1
```

The `ping` command works because it was installed when we committed the image.

### Cleanup

```bash
docker container rm sample
```

### Note

Interactive creation is useful for learning but **not recommended for production**. Changes aren't documented or reproducible. Use Dockerfiles instead.

---

## Part 3: Understanding Dockerfiles

A **Dockerfile** is a text file containing instructions to build an image. It's the preferred way to create images because it's:

- **Declarative** – describes what the image should contain
- **Reproducible** – anyone can rebuild the same image
- **Version-controlled** – can be stored in Git

### Dockerfile Structure

```dockerfile
FROM base-image:tag
RUN command-to-execute
COPY source destination
WORKDIR /path
CMD ["default", "command"]
```

### Common Instructions

| Instruction | Description |
|-------------|-------------|
| `FROM` | Base image to build upon |
| `RUN` | Execute a command during build |
| `COPY` | Copy files from host to image |
| `ADD` | Like COPY, but can extract archives and fetch URLs |
| `WORKDIR` | Set the working directory |
| `ENV` | Set environment variables |
| `EXPOSE` | Document which ports the container listens on |
| `CMD` | Default command when container starts |
| `ENTRYPOINT` | Main executable (CMD becomes arguments) |

### Key Concept: Layers

Each instruction in a Dockerfile creates a new **layer**. Layers are cached, so unchanged instructions don't need to be rebuilt.

---

## Part 4: Building Your First Image with a Dockerfile

Let's create a simple image that has `wget` installed.

### Create a Working Directory

```bash
mkdir -p ~/lab/images && cd ~/lab/images
```

### Create a Dockerfile

```bash
cat > Dockerfile <<'EOF'
FROM alpine
RUN apk update && apk add wget
CMD ["wget", "--version"]
EOF
```

### Build the Image

```bash
docker image build -t my-wget .
```

**Note:** The `.` at the end specifies the **build context** (current directory).

### Understanding the Build Output

```
Sending build context to Docker daemon  2.048kB
Step 1/3 : FROM alpine
 ---> ...
Step 2/3 : RUN apk update && apk add wget
 ---> Running in abc123...
 ---> ...
Step 3/3 : CMD ["wget", "--version"]
 ---> ...
Successfully built def456...
Successfully tagged my-wget:latest
```

The builder:
1. Sends files from the current directory to the Docker daemon
2. Pulls the base image (if not cached)
3. Creates a container, runs each instruction, and commits the result
4. Tags the final image

### Test the Image

```bash
docker container run --rm my-wget
```

You should see wget's version information.

### Run a Custom Command

```bash
docker container run --rm my-wget wget -O- -q https://httpbin.org/get
```

---

## Part 5: A More Complete Dockerfile Example

Let's create an image for a simple web server.

### Create a New Directory

```bash
mkdir -p ~/lab/webserver && cd ~/lab/webserver
```

### Create an HTML File

```bash
cat > index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker Lab</title>
</head>
<body>
    <h1>Hello from a Custom Docker Image!</h1>
    <p>This page is served from a container.</p>
</body>
</html>
EOF
```

### Create the Dockerfile

```bash
cat > Dockerfile <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
```

### Build the Image

```bash
docker image build -t my-webserver .
```

### Run the Container

```bash
docker container run -d --name web -p 8080:80 my-webserver
```

### Test It

```bash
curl localhost:8080
```

You should see your custom HTML page.

### PWD Note (Browser Access)

In Play with Docker, click the **8080** port link at the top to view in browser.

### Cleanup

```bash
docker container rm -f web
```

---

## Part 6: Tagging Images

Tags help you version and organize images. The format is:

```
repository:tag
```

If you omit the tag, Docker uses `latest` by default.

### Tag an Existing Image

```bash
docker image tag my-webserver my-webserver:1.0
docker image tag my-webserver my-webserver:stable
```

### List Images

```bash
docker image ls | grep my-webserver
```

You'll see:

```
my-webserver   1.0      abc123...   2 minutes ago   45MB
my-webserver   latest   abc123...   2 minutes ago   45MB
my-webserver   stable   abc123...   2 minutes ago   45MB
```

Notice they all have the **same Image ID**—they're the same image with different tags.

### Tag for a Registry

To push to Docker Hub, the image name must include your username:

```bash
docker image tag my-webserver <your-dockerhub-username>/my-webserver:1.0
```

Replace `<your-dockerhub-username>` with your actual Docker Hub username.

---

## Part 7: Saving and Loading Images

Sometimes you need to transfer images without a registry—for example, to an air-gapped system.

### Save an Image to a File

```bash
mkdir -p ~/backup
docker image save -o ~/backup/my-webserver.tar my-webserver:latest
```

### View the Archive

```bash
ls -lh ~/backup/my-webserver.tar
```

### Remove the Local Image (to simulate transfer)

```bash
docker image rm my-webserver:latest my-webserver:1.0 my-webserver:stable
docker image ls | grep my-webserver
```

The image is gone.

### Load the Image from File

```bash
docker image load -i ~/backup/my-webserver.tar
```

### Verify

```bash
docker image ls | grep my-webserver
```

The image is back.

---

## Part 8: Pushing Images to Docker Hub

To share images publicly (or privately), push them to a registry.

### Prerequisites

- A Docker Hub account (free at https://hub.docker.com)

### Login to Docker Hub

```bash
docker login
```

Enter your username and password when prompted.

### Tag the Image for Your Account

```bash
docker image tag my-webserver <your-dockerhub-username>/my-webserver:1.0
```

### Push the Image

```bash
docker image push <your-dockerhub-username>/my-webserver:1.0
```

You'll see output like:

```
The push refers to repository [docker.io/<your-username>/my-webserver]
abc123: Pushed
def456: Mounted from library/nginx
1.0: digest: sha256:... size: 1234
```

### Verify on Docker Hub

Visit `https://hub.docker.com/r/<your-username>/my-webserver` to see your image.

### Pull on Another Machine

Anyone (or any machine) can now pull your image:

```bash
docker image pull <your-dockerhub-username>/my-webserver:1.0
```

---

## Exercises

### Exercise 1: Build a Custom Image

1. Create a Dockerfile based on `alpine` that installs `curl` and `jq`
2. Set the default command to display curl's version
3. Build it as `my-tools:1.0`
4. Run it and verify both tools are installed

**Hints:**

```bash
mkdir -p ~/lab/tools && cd ~/lab/tools

cat > Dockerfile <<'EOF'
FROM alpine
RUN apk update && apk add curl jq
CMD ["curl", "--version"]
EOF

docker image build -t my-tools:1.0 .
docker container run --rm my-tools:1.0
docker container run --rm my-tools:1.0 jq --version
```

### Exercise 2: Understand Layer Caching

1. Build the `my-tools` image again (without changes)
2. Observe that it uses cached layers
3. Modify the Dockerfile to add `git`
4. Rebuild and observe which layers are rebuilt

**Observation:** Docker reuses cached layers until it encounters a changed instruction.

### Exercise 3: Interactive Commit with a Message

1. Run an Ubuntu container interactively
2. Install `vim` inside it
3. Commit with a message and author

```bash
docker container run -it --name vim-test ubuntu:22.04 bash
```

Inside the container:

```bash
apt update && apt install -y vim
exit
```

Commit with metadata:

```bash
docker container commit -m "Added vim editor" -a "Your Name" vim-test my-ubuntu-vim:1.0
docker image inspect my-ubuntu-vim:1.0 | grep -A2 "Author"
```

---

## Optional Advanced Exercises (Intermediate)

> **Context:** You're a DevOps engineer at a growing startup. The team has been building Docker images, but deployments are slow, images are huge, and builds are inconsistent. Your job: optimize the image pipeline.

---

## Part 9 (Optional): Multi-Stage Builds

Your team's application image is 500MB and takes forever to deploy. The image includes compilers, build tools, and source code—none of which are needed at runtime.

Multi-stage builds let you use one stage to build your application and another stage with only the final artifact.

### Create a Sample C Program

```bash
mkdir -p ~/lab/multistage && cd ~/lab/multistage

cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) {
    printf("Hello from a multi-stage build!\n");
    return 0;
}
EOF
```

### The "Naive" Single-Stage Approach

```bash
cat > Dockerfile.single <<'EOF'
FROM alpine
RUN apk update && apk add build-base
WORKDIR /app
COPY hello.c .
RUN gcc -o hello hello.c
CMD ["/app/hello"]
EOF

docker image build -t hello-single -f Dockerfile.single .
docker image ls | grep hello-single
```

Notice the size—it includes the entire compiler toolchain.

### The Multi-Stage Approach

```bash
cat > Dockerfile.multi <<'EOF'
# Stage 1: Build
FROM alpine AS build
RUN apk update && apk add build-base
WORKDIR /app
COPY hello.c .
RUN gcc -o hello hello.c

# Stage 2: Runtime (only the binary)
FROM alpine
COPY --from=build /app/hello /app/hello
CMD ["/app/hello"]
EOF

docker image build -t hello-multi -f Dockerfile.multi .
docker image ls | grep hello
```

### Compare the Sizes

```bash
docker image ls | grep hello
```

You should see something like:

```
hello-multi    latest   ...   5 seconds ago    8MB
hello-single   latest   ...   30 seconds ago   180MB
```

The multi-stage image is **~20x smaller** because it only contains the binary, not the build tools.

### Test It

```bash
docker container run --rm hello-multi
```

---

## Part 10 (Optional): Build Context and .dockerignore

A developer complains that builds are slow. You investigate and find they're sending 2GB of node_modules and log files to the Docker daemon—even though none of it is needed.

When you run `docker image build`, everything in the current directory (the **build context**) is sent to the daemon. Large unnecessary files slow this down.

### Simulate a Large Context

```bash
mkdir -p ~/lab/context && cd ~/lab/context

# Create a "large" file
dd if=/dev/zero of=large-file.bin bs=1M count=50

# Create a simple Dockerfile
cat > Dockerfile <<'EOF'
FROM alpine
RUN echo "Hello"
EOF
```

### Build Without .dockerignore

```bash
docker image build -t context-test .
```

Notice the first line: `Sending build context to Docker daemon 52.43MB`

### Create a .dockerignore File

```bash
cat > .dockerignore <<'EOF'
large-file.bin
*.log
node_modules/
.git/
EOF
```

### Build Again

```bash
docker image build -t context-test .
```

Now it should say: `Sending build context to Docker daemon 2.56kB`

Much faster! The `.dockerignore` file works like `.gitignore`—it excludes files from the build context.

### Cleanup

```bash
rm large-file.bin
```

---

## Part 11 (Optional): Layer Caching Strategy

Developers keep complaining that builds take forever. Every small code change triggers a complete rebuild of all dependencies.

The key insight: Docker caches layers **until it hits a changed instruction**. After that, everything is rebuilt.

### Bad Dockerfile (dependencies reinstalled on every code change)

```bash
mkdir -p ~/lab/caching && cd ~/lab/caching

cat > app.py <<'EOF'
print("Hello from Python!")
EOF

cat > requirements.txt <<'EOF'
requests==2.31.0
EOF

cat > Dockerfile.bad <<'EOF'
FROM python:3.11-alpine
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
EOF
```

Build it:

```bash
docker image build -t cache-bad -f Dockerfile.bad .
```

Now change the code and rebuild:

```bash
echo 'print("Updated!")' > app.py
docker image build -t cache-bad -f Dockerfile.bad .
```

Notice: `pip install` runs again even though `requirements.txt` didn't change!

### Good Dockerfile (dependencies cached separately)

```bash
cat > Dockerfile.good <<'EOF'
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF
```

Build it:

```bash
docker image build -t cache-good -f Dockerfile.good .
```

Change the code and rebuild:

```bash
echo 'print("Updated again!")' > app.py
docker image build -t cache-good -f Dockerfile.good .
```

Notice: `pip install` says `Using cache`! Only the code copy is re-executed.

### The Rule

Copy files that change **frequently** (code) **after** files that change **rarely** (dependencies).

---

## Part 12 (Optional): Build Arguments (ARG)

Your team needs to build the same application for different environments—dev, staging, production—with different configurations.

Build arguments let you parameterize your Dockerfile.

```bash
mkdir -p ~/lab/args && cd ~/lab/args

cat > Dockerfile <<'EOF'
FROM alpine
ARG APP_ENV=development
ARG APP_VERSION=1.0.0
ENV APP_ENV=${APP_ENV}
ENV APP_VERSION=${APP_VERSION}
RUN echo "Building for ${APP_ENV}, version ${APP_VERSION}"
CMD echo "Running in ${APP_ENV} mode, version ${APP_VERSION}"
EOF
```

### Build with Default Arguments

```bash
docker image build -t myapp:dev .
docker container run --rm myapp:dev
```

### Build with Custom Arguments

```bash
docker image build --build-arg APP_ENV=production --build-arg APP_VERSION=2.0.0 -t myapp:prod .
docker container run --rm myapp:prod
```

The same Dockerfile produces different images based on build-time arguments.

---

## Part 13 (Optional): Adding Metadata with LABEL

Your organization has hundreds of images. Nobody knows who built them, when, or from which Git commit. You need to add metadata.

```bash
mkdir -p ~/lab/labels && cd ~/lab/labels

cat > Dockerfile <<'EOF'
FROM alpine
LABEL maintainer="devops@company.com"
LABEL org.opencontainers.image.title="My Application"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="A sample application for the Docker lab"
LABEL org.opencontainers.image.source="https://github.com/company/myapp"
CMD ["echo", "Hello from a labeled image!"]
EOF

docker image build -t labeled-app .
```

### View the Labels

```bash
docker image inspect labeled-app | jq '.[0].Config.Labels'
```

You can now query images by label:

```bash
docker image ls --filter "label=maintainer=devops@company.com"
```

---

## Part 14 (Optional): Inspecting Image Layers

A security scan flagged a vulnerability in one of your image layers. You need to understand what's in each layer to find the source.

### Inspect an Image

```bash
docker image inspect my-webserver
```

This shows the full configuration, including layers, environment variables, and commands.

### View Layer History

```bash
docker image history my-webserver
```

This shows each layer, its size, and the command that created it.

### See Layer Details

```bash
docker image history --no-trunc my-webserver
```

The `--no-trunc` flag shows full commands (useful for debugging).

### Export and Examine Layers

```bash
mkdir -p ~/lab/layers && cd ~/lab/layers
docker image save my-webserver -o image.tar
tar -tvf image.tar | head -20
```

Each layer is a separate tarball inside the image archive.

---

## Part 15 (Optional): Choosing Base Images Wisely

Your security team reports that your images have hundreds of vulnerabilities. Most come from unnecessary packages in the base image.

### Compare Base Image Sizes

```bash
docker image pull ubuntu:22.04
docker image pull debian:bookworm-slim
docker image pull alpine
docker image pull gcr.io/distroless/static-debian12

docker image ls | grep -E "ubuntu|debian|alpine|distroless"
```

Typical sizes:
- Ubuntu: ~77MB
- Debian Slim: ~74MB
- Alpine: ~7MB
- Distroless: ~2MB

### The Trade-offs

| Base Image | Size | Package Manager | Shell | Use Case |
|------------|------|-----------------|-------|----------|
| Ubuntu/Debian | Large | apt | Yes | Development, debugging |
| Alpine | Small | apk | Yes | General purpose, small footprint |
| Distroless | Tiny | None | No | Production, maximum security |

### Recommendation

- **Development:** Use Ubuntu or Debian for familiarity
- **Production:** Use Alpine or Distroless for smaller attack surface

---

## Key Takeaways

- Images are **read-only templates** made of layers
- **Dockerfiles** are the standard way to create reproducible images
- Each Dockerfile instruction creates a **new layer**
- **Layer caching** speeds up builds—order instructions from least to most frequently changed
- **Multi-stage builds** dramatically reduce image size
- **Tags** help version and organize images
- `.dockerignore` prevents unnecessary files from entering the build context
- Choose **minimal base images** for production

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `docker image build -t name .` | Build image from Dockerfile |
| `docker image build -f Dockerfile.custom .` | Build with specific Dockerfile |
| `docker image ls` | List local images |
| `docker image rm name` | Remove an image |
| `docker image tag src dest` | Create a new tag for an image |
| `docker image push name` | Push image to registry |
| `docker image pull name` | Pull image from registry |
| `docker image save -o file.tar name` | Export image to tarball |
| `docker image load -i file.tar` | Import image from tarball |
| `docker image inspect name` | View image metadata |
| `docker image history name` | View image layers |
| `docker image prune` | Remove unused images |
| `docker container commit container image` | Create image from container |

---

## Cleanup (End of Lab)

```bash
# Remove containers
docker container rm -f sample web vim-test 2>/dev/null || true
docker container prune -f

# Remove lab images
docker image rm my-alpine my-wget my-webserver my-tools:1.0 2>/dev/null || true
docker image rm my-ubuntu-vim:1.0 hello-single hello-multi 2>/dev/null || true
docker image rm context-test cache-bad cache-good myapp:dev myapp:prod labeled-app 2>/dev/null || true

# Remove build directories (optional)
rm -rf ~/lab ~/backup

# Remove dangling images
docker image prune -f
```


