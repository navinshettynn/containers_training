# Docker Networking – Hands-on Lab (Play with Docker)

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

- Understand Docker's **default networking behavior**
- Explore the **bridge**, **host**, and **none** network drivers
- Create and manage **custom bridge networks**
- Enable **container-to-container communication** using DNS
- **Publish ports** to expose container services
- Inspect networks and troubleshoot connectivity issues

### Intermediate Objectives (Optional)

- Connect containers to **multiple networks**
- Use **network aliases** for service discovery
- Understand **network isolation** and security boundaries
- Troubleshoot networking issues with common tools
- Control container DNS and hostname settings
- Explore **macvlan** networks for direct LAN access

### Tip: Use a Name Prefix

On shared hosts or busy workstations, prefix container/network names (e.g., `lab-web`, `lab-mynet`) so you don't clash with existing resources.

---

## Quick Sanity Check

Verify Docker is installed and networking is available:

```bash
docker version
docker network ls
```

You should see three default networks:

```
NETWORK ID     NAME      DRIVER    SCOPE
abc123...      bridge    bridge    local
def456...      host      host      local
ghi789...      none      null      local
```

---

## Part 1: Understanding Default Networks

Docker provides three built-in networks. Let's explore what each does.

### List Available Networks

```bash
docker network ls
```

| Network | Driver | Description |
|---------|--------|-------------|
| `bridge` | bridge | Default network for containers; provides NAT to host |
| `host` | host | Container shares host's network stack directly |
| `none` | null | Container has no network access |

### Inspect the Default Bridge Network

```bash
docker network inspect bridge
```

Key sections to notice:

- **Subnet**: Usually `172.17.0.0/16`
- **Gateway**: Usually `172.17.0.1`
- **Containers**: List of connected containers

---

## Part 2: The Default Bridge Network

When you run a container without specifying a network, it connects to the default `bridge` network.

### Run Two Containers on the Default Bridge

```bash
docker container run -d --name c1 alpine sleep 3600
docker container run -d --name c2 alpine sleep 3600
```

### Get Their IP Addresses

```bash
docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c1
docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c2
```

You should see IPs like `172.17.0.2` and `172.17.0.3`.

### Test Connectivity by IP

```bash
docker container exec c1 ping -c 3 172.17.0.3
```

Replace `172.17.0.3` with c2's actual IP. The ping should succeed.

### Try Connectivity by Name

```bash
docker container exec c1 ping -c 3 c2
```

**Expected result:** This fails!

```
ping: bad address 'c2'
```

### Observation

The default bridge network **does not provide DNS resolution** between containers. You must use IP addresses, which is fragile and not recommended.

### Cleanup

```bash
docker container rm -f c1 c2
```

---

## Part 3: Custom Bridge Networks (User-Defined Networks)

Custom bridge networks solve the DNS problem and provide better isolation.

### Create a Custom Network

```bash
docker network create mynet
```

### Verify It Was Created

```bash
docker network ls | grep mynet
```

### Inspect the New Network

```bash
docker network inspect mynet
```

Notice it has its own subnet (e.g., `172.18.0.0/16`).

### Run Containers on the Custom Network

```bash
docker container run -d --name web --network mynet nginx:alpine
docker container run -d --name client --network mynet alpine sleep 3600
```

### Test DNS Resolution

```bash
docker container exec client ping -c 3 web
```

**Expected result:** Success!

```
PING web (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.123 ms
...
```

### Test HTTP Connectivity

```bash
docker container exec client wget -qO- http://web
```

You should see the Nginx welcome page HTML.

### Observation

Custom bridge networks provide:

- **Automatic DNS resolution** by container name
- **Better isolation** from containers on other networks
- **No need to manage IP addresses**

---

## Part 4: Publishing Ports

To make container services accessible from outside Docker, you publish ports.

### Port Publishing Syntax

| Flag | Description |
|------|-------------|
| `-p 8080:80` | Map host port 8080 to container port 80 |
| `-p 80` | Map a random host port to container port 80 |
| `-p 127.0.0.1:8080:80` | Bind only to localhost |
| `-P` | Publish all exposed ports to random host ports |

### Run Nginx with Published Port

```bash
docker container run -d --name webserver -p 8080:80 nginx:alpine
```

### Verify the Port Mapping

```bash
docker container ls
```

You should see `0.0.0.0:8080->80/tcp` in the PORTS column.

### Test from Host

```bash
curl localhost:8080
```

You should see the Nginx welcome page.

### PWD Note (Browser Access)

In Play with Docker, click the **8080** port link that appears at the top of the terminal to view in your browser.

### Check Which Ports Are Published

```bash
docker container port webserver
```

Output:

```
80/tcp -> 0.0.0.0:8080
```

### Cleanup

```bash
docker container rm -f webserver
```

---

## Part 5: The Host Network

The `host` network removes network isolation—the container shares the host's network stack directly.

### Run Nginx on Host Network

```bash
docker container run -d --name hostnet --network host nginx:alpine
```

### Test It

```bash
curl localhost:80
```

The container is directly accessible on the host's port 80 (no mapping needed).

### Check Container Network Settings

```bash
docker container inspect -f '{{json .NetworkSettings.Networks}}' hostnet | jq
```

There's no IP address because the container uses the host's network.

### When to Use Host Network

- **Performance-critical** applications (no NAT overhead)
- **Network monitoring** tools that need to see all host traffic
- **When you need access to host network interfaces**

### Trade-offs

- No port mapping flexibility
- Potential port conflicts with host services
- Reduced isolation

### Cleanup

```bash
docker container rm -f hostnet
```

---

## Part 6: The None Network

The `none` network completely disables networking for a container.

### Run a Container with No Network

```bash
docker container run --rm --network none alpine ip addr
```

You should see only the `lo` (loopback) interface:

```
1: lo: <LOOPBACK,UP,LOWER_UP> ...
    inet 127.0.0.1/8 scope host lo
```

### When to Use None Network

- **Security-sensitive** batch jobs that shouldn't have network access
- **Testing** how applications behave without network
- **Isolated computation** tasks

---

## Part 7: Connecting Containers to Multiple Networks

A container can connect to multiple networks simultaneously.

### Create Two Networks

```bash
docker network create frontend
docker network create backend
```

### Run a Container on Frontend

```bash
docker container run -d --name app --network frontend alpine sleep 3600
```

### Connect It to Backend as Well

```bash
docker network connect backend app
```

### Verify the Container's Networks

```bash
docker container inspect -f '{{json .NetworkSettings.Networks}}' app | jq 'keys'
```

Output:

```json
[
  "backend",
  "frontend"
]
```

### Get Both IP Addresses

```bash
docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' app
```

The container now has an IP on each network and can communicate with containers on both.

### Disconnect from a Network

```bash
docker network disconnect frontend app
```

### Cleanup

```bash
docker container rm -f app
docker network rm frontend backend
```

---

## Part 8: Inspecting and Troubleshooting Networks

### View Network Details

```bash
docker network inspect mynet
```

Key information:

- **Driver**: Network type (bridge, overlay, etc.)
- **IPAM Config**: Subnet and gateway
- **Containers**: All connected containers with their IPs

### Find All Containers on a Network

```bash
docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' mynet
```

### Check Container's Network Configuration

```bash
docker container inspect -f '{{json .NetworkSettings}}' web | jq
```

### Test Connectivity Inside a Container

Attach to a container and use networking tools:

```bash
docker container exec -it client sh
```

Inside the container:

```sh
# Check IP configuration
ip addr

# Check routing table
ip route

# Check DNS resolution
nslookup web

# Test HTTP
wget -qO- http://web

exit
```

---

## Exercises

### Exercise 1: Build a Simple Web Application Network

Create a typical web application setup:

1. Create a custom network called `webapp`
2. Run a database container (use Alpine with sleep for simulation)
3. Run an application container
4. Verify they can communicate by name

```bash
docker network create webapp
docker container run -d --name db --network webapp alpine sleep 3600
docker container run -d --name app --network webapp alpine sleep 3600

# Test connectivity
docker container exec app ping -c 3 db
```

Cleanup:

```bash
docker container rm -f db app
docker network rm webapp
```

### Exercise 2: Port Publishing Practice

1. Run Nginx on port 9090
2. Run another Nginx on a random port
3. Find the random port and test both

```bash
docker container run -d --name web1 -p 9090:80 nginx:alpine
docker container run -d --name web2 -p 80 nginx:alpine

# Find web2's random port
docker container port web2

# Test both
curl localhost:9090
curl localhost:<random-port>
```

Cleanup:

```bash
docker container rm -f web1 web2
```

### Exercise 3: Network Isolation Test

Demonstrate that containers on different networks cannot communicate:

1. Create two separate networks
2. Run one container on each
3. Try to ping between them

```bash
docker network create net1
docker network create net2

docker container run -d --name box1 --network net1 alpine sleep 3600
docker container run -d --name box2 --network net2 alpine sleep 3600

# Get box2's IP
docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' box2

# Try to ping from box1 (should fail)
docker container exec box1 ping -c 3 <box2-ip>
```

The ping will timeout or fail because the networks are isolated.

Cleanup:

```bash
docker container rm -f box1 box2
docker network rm net1 net2
```

---

## Optional Advanced Exercises (Intermediate)

> **Context:** You're the network engineer for a growing startup. The team is deploying microservices and needs reliable, secure container networking. Your job: design networks that are scalable, debuggable, and secure.

---

## Part 9 (Optional): Network Aliases

Your team is building a high-availability setup where multiple containers serve the same role. They want a single DNS name that resolves to any of them.

Network aliases let you give a container additional DNS names.

### Create a Network and Containers with Aliases

```bash
docker network create backend

docker container run -d --name api1 --network backend --network-alias api alpine sleep 3600
docker container run -d --name api2 --network backend --network-alias api alpine sleep 3600
docker container run -d --name client --network backend alpine sleep 3600
```

Both `api1` and `api2` respond to the name `api`.

### Test DNS Resolution

```bash
docker container exec client nslookup api
```

You should see both IP addresses:

```
Name:      api
Address 1: 172.19.0.2 api1.backend
Address 2: 172.19.0.3 api2.backend
```

### Ping the Alias

```bash
docker container exec client ping -c 3 api
```

Docker's embedded DNS does round-robin, so requests can go to either container. This is a simple form of load balancing.

### Cleanup

```bash
docker container rm -f api1 api2 client
docker network rm backend
```

---

## Part 10 (Optional): Custom Subnets and Gateways

Your organization uses a specific IP addressing scheme. You need containers to use predictable subnets.

### Create a Network with Custom IPAM

```bash
docker network create \
  --subnet=10.10.0.0/24 \
  --gateway=10.10.0.1 \
  --ip-range=10.10.0.128/25 \
  customnet
```

| Option | Description |
|--------|-------------|
| `--subnet` | The network's address range |
| `--gateway` | The gateway IP for the network |
| `--ip-range` | Subset of subnet for container IPs |

### Verify the Configuration

```bash
docker network inspect customnet | jq '.[0].IPAM.Config'
```

### Run a Container with a Specific IP

```bash
docker container run -d --name fixed-ip --network customnet --ip 10.10.0.200 alpine sleep 3600
```

### Verify the IP

```bash
docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' fixed-ip
```

Output: `10.10.0.200`

### Cleanup

```bash
docker container rm -f fixed-ip
docker network rm customnet
```

---

## Part 11 (Optional): Container DNS Configuration

Your application needs to use specific DNS servers or have a custom hostname.

### Custom DNS Servers

```bash
docker container run --rm --dns 8.8.8.8 --dns 8.8.4.4 alpine cat /etc/resolv.conf
```

You should see Google's DNS servers listed.

### Custom Hostname

```bash
docker container run --rm --hostname myapp.local alpine hostname
```

Output: `myapp.local`

### Custom Hosts File Entries

```bash
docker container run --rm --add-host db.local:192.168.1.100 alpine cat /etc/hosts
```

You'll see the custom entry added:

```
192.168.1.100   db.local
```

### Combine Options

```bash
docker container run -d --name customdns \
  --hostname api-server \
  --dns 8.8.8.8 \
  --add-host database:10.0.0.50 \
  --network mynet \
  alpine sleep 3600
```

### Cleanup

```bash
docker container rm -f customdns 2>/dev/null || true
```

---

## Part 12 (Optional): Network Troubleshooting Toolkit

Something isn't working. Containers can't connect. You need to diagnose the issue.

### Create a Debug Container

The `nicolaka/netshoot` image includes common networking tools (curl, dig, nmap, tcpdump, etc.):

```bash
docker container run -it --rm --network mynet nicolaka/netshoot
```

Inside the container, you have access to:

```sh
# DNS lookup
dig web
nslookup web

# HTTP testing
curl -v http://web

# TCP connection test
nc -zv web 80

# Trace route
traceroute web

# Network scanning
nmap -sn 172.18.0.0/24

exit
```

### Attach to a Running Container's Network Namespace

Debug network issues from another container's perspective:

```bash
docker container run -it --rm --network container:web nicolaka/netshoot
```

This shares the network namespace with the `web` container—you see exactly what `web` sees.

### Inspect Traffic with tcpdump

```bash
docker container run -it --rm --network mynet nicolaka/netshoot tcpdump -i eth0 port 80
```

In another terminal, generate traffic:

```bash
docker container exec client wget -qO- http://web
```

You'll see the HTTP traffic in the tcpdump output.

---

## Part 13 (Optional): Macvlan Networks

Your legacy application needs to appear as a physical device on the LAN with its own MAC address.

Macvlan networks let containers get IP addresses directly from your physical network.

### Note

Macvlan requires specific host network configuration and may not work in all environments (including PWD). This is primarily for bare-metal or VM hosts with proper network access.

### Create a Macvlan Network

```bash
# Replace eth0 with your actual interface name
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  lannet
```

### Run a Container on the LAN

```bash
docker container run -d --name lanbox --network lannet --ip 192.168.1.200 alpine sleep 3600
```

The container now has IP `192.168.1.200` on your physical network and can communicate with other LAN devices directly.

### When to Use Macvlan

- Legacy applications expecting to be on the LAN
- Applications requiring their own MAC address
- Avoiding NAT for performance or compatibility

### Trade-offs

- Host cannot directly communicate with macvlan containers
- Requires promiscuous mode on the parent interface
- More complex setup

### Cleanup

```bash
docker container rm -f lanbox 2>/dev/null || true
docker network rm lannet 2>/dev/null || true
```

---

## Part 14 (Optional): Network Security and Isolation

Your security team wants to ensure containers in different environments (dev, staging, prod) cannot accidentally communicate.

### Demonstrate Network Isolation

```bash
docker network create production
docker network create development

docker container run -d --name prod-api --network production alpine sleep 3600
docker container run -d --name dev-api --network development alpine sleep 3600

# Get prod-api's IP
PROD_IP=$(docker container inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' prod-api)
echo "Production API IP: $PROD_IP"

# Try to reach production from development
docker container exec dev-api ping -c 3 $PROD_IP
```

The ping times out—networks are isolated by default.

### Internal Networks

Create a network that has no external connectivity:

```bash
docker network create --internal isolated
docker container run --rm --network isolated alpine ping -c 1 8.8.8.8
```

The ping fails because the `--internal` flag prevents external access.

### Cleanup

```bash
docker container rm -f prod-api dev-api 2>/dev/null || true
docker network rm production development isolated 2>/dev/null || true
```

---

## Part 15 (Optional): Docker Compose Networking Preview

When you use Docker Compose, it automatically creates networks for your services.

Create a simple compose file:

```bash
mkdir -p ~/lab/compose && cd ~/lab/compose

cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
  api:
    image: alpine
    command: sleep 3600
EOF
```

Start the services:

```bash
docker compose up -d
```

Check the network:

```bash
docker network ls | grep compose
```

Compose created a network named `compose_default` (based on the directory name).

Both containers can reach each other by service name:

```bash
docker compose exec api ping -c 3 web
```

Cleanup:

```bash
docker compose down
cd ~
rm -rf ~/lab/compose
```

---

## Key Takeaways

- Docker provides **three default networks**: bridge, host, and none
- The **default bridge** network does NOT provide DNS between containers
- **Custom bridge networks** enable DNS resolution by container name
- Use **port publishing** (`-p`) to expose services outside Docker
- Containers can connect to **multiple networks** simultaneously
- **Network aliases** allow multiple containers to share a DNS name
- Networks provide **isolation**—containers on different networks can't communicate
- Use **`docker network inspect`** and debugging tools to troubleshoot issues

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `docker network ls` | List all networks |
| `docker network create NAME` | Create a custom bridge network |
| `docker network create --driver host NAME` | Create with specific driver |
| `docker network rm NAME` | Remove a network |
| `docker network inspect NAME` | View network details |
| `docker network connect NET CONTAINER` | Connect container to network |
| `docker network disconnect NET CONTAINER` | Disconnect from network |
| `docker container run --network NAME` | Run container on specific network |
| `docker container run -p 8080:80` | Publish port 80 to host port 8080 |
| `docker container run --network host` | Use host network stack |
| `docker container run --network none` | Disable networking |
| `docker container run --network-alias NAME` | Add DNS alias |
| `docker container port NAME` | Show port mappings |
| `docker network prune` | Remove unused networks |

---

## Cleanup (End of Lab)

```bash
# Remove containers
docker container rm -f c1 c2 web client webserver hostnet 2>/dev/null || true
docker container rm -f app db box1 box2 api1 api2 2>/dev/null || true
docker container rm -f web1 web2 fixed-ip customdns 2>/dev/null || true
docker container rm -f prod-api dev-api lanbox 2>/dev/null || true
docker container prune -f

# Remove custom networks
docker network rm mynet webapp net1 net2 backend 2>/dev/null || true
docker network rm frontend customnet production development 2>/dev/null || true
docker network rm isolated lannet 2>/dev/null || true
docker network prune -f

# Remove compose project (if created)
rm -rf ~/lab/compose
```


