# dorg's NixOS configs

A flake-based NixOS configuration managing a set of hardened, ZFS-backed headless systems. Going to be used for d.org XMPP.

## Overview

This repository defines the system configuration for two hosts:

### armaku
- Single AirDisk 240GB SSD, GPT partitioned into ESP / swap (randomly-encrypted) / LUKS-encrypted root.
- ZFS pool `zroot` on top of LUKS, with datasets for `/nix`, `/srv/media` (large recordsize, no compression), and an XMPP container dataset.
- Probably has more reliable uptime and faster networking than Quill. Maybe not by much
- Has static IP
- Low storage (240GB)

### quill
- Separate boot disk (`zboot`: ESP + swap + ZFS root/nix) and three 8TB drives in a RAIDZ1 pool (`zdata`) for bulk storage and container data.
- Disk encryption not needed (only ever touched by Quill themself).
- No static IP. Could be solved with dynamic DNS.
- Has tons of storage (24TB)

Both hosts run monthly ZFS scrubs and use `lz4`/`zstd` compression tuned per dataset.

Both hosts are built as minimal, headless, hardened NixOS systems using
[disko](https://github.com/nix-community/disko) for declarative disk
partitioning and ZFS pool/dataset layout, and
[lanzaboote](https://github.com/nix-community/lanzaboote) for Secure Boot
support.

## Repo Layout

```
.
├── flake.nix                     # Entry point wires hosts + shared modules together
├── containers/
│   └── xmpp.nix                  # XMPP server configuration and container configuration
├── lib/
│   └── hardened-service.nix      # Shared systemd sandboxing profile (hardening.mkService)
├── modules/                      # Shared NixOS modules, applied to every host
│   ├── boot.nix                  # Kernel, sysctls, boot params
│   ├── meta-settings.nix         # settings for nix
│   ├── networking.nix            # systemd-networkd, systemd-resolved, firewall
│   ├── reduce-closure-size.nix    
│   ├── ssh.nix                   # hardened sshd unit service + authorized keys
│   ├── users.nix                 # user account
│   └── security/
│       ├── disable-setuid.nix           # Disables sudo/su/mount setuid wrappers, uses polkit
│       ├── disabled-kernel-modules.nix  # blacklists kernel modules used in dirtyfrag (see Security section)
│       └── hardened-services/           # sandboxes services
│           ├── zfs-services.nix
│           ├── nscd.nix
│           └── acpid.nix
└── systems/
    ├── armaku/
    │   ├── default.nix                 # Host module imports (disk layout + minimal/perlless/headless profiles)
    │   ├── disk-layout.nix             # disko: LUKS + single-disk ZFS layout
    │   └── hardware-configuration.nix  # CPU/firmware/initrd settings
    └── quill/
        ├── default.nix
        ├── disk-layout.nix             # disko: boot pool + 3-disk RAIDZ1 data pool
        └── hardware-configuration.nix
```

## How It Works

- **`flake.nix`** discovers every directory under `./systems/` and builds a
  `nixosConfiguration` for each, automatically pulling in every `.nix` file
  under `./modules/` as a shared module for all hosts.
- **`hardening.mkService`** (from `lib/hardened-service.nix`) provides a
  reusable, network-locked-down systemd sandboxing profile. Individual
  services opt into networking with `networking = true`, otherwise they get a
  restrictive default profile (no new privileges, private mounts/network,
  restricted syscalls, denied address families, etc).
- **Disk layout** is fully declarative via disko. Each host's defines partitioning,
  LUKS (where applicable), ZFS pools,
  and datasets, including per-dataset tuning (recordsize, compression,
  auto-snapshot policy) for use cases like `/nix`, media storage,
  and container storage.
- **Secure Boot** is enabled via lanzaboote with auto-generated and
  auto-enrolled keys (see the setup notes at the bottom of
  `modules/security/secure-boot.nix` for the manual `sbctl` steps required
  once).
- The **XMPP server** defined in `containers/xmpp.nix` runs in a NixOS container upon 
  boot. Packets are forwarded from the host to the container. `/srv/media` is bind 
  mounted in the container for the XMPP server to access.

## Security

- Minimal setuid binaries. Privilege escalation goes through `run0`/`polkit`.
- SSH is key-only (no password auth, no root login), with a sandboxed `sshd` service.
- Most system services run under a shared hardened systemd profile denying network access, kernel module loading, real-time scheduling, and a large set of syscalls by default.
- Secure Boot via lanzaboote.
- DNS-over-TLS via `systemd-resolved` (Quad9 primary, Cloudflare/Google fallback).
- A couple of kernel modules (`esp4`, `esp6`, `rxrpc`) are blacklisted as a mitigation for known [kernel vulnerabilities](https://github.com/V4bel/dirtyfrag).

## Usage

Build or switch a specific host (from a machine with this flake and appropriate privileges):

```bash
# build system without switching
nixos-rebuild build --flake .#(hostname)

# Deploy to a remote host
nixos-rebuild switch --flake .#armaku --target-host dorg@(hostname) --ask-elevate-password --elevate=run0
```

To install/deploy for the first time on a machine:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#[hostname] \
  --disk-encryption-keys /etc/ssh/ssh_host_ed25519_key <(sops -d --extract '["age_key"]' secrets/[hostname].yaml) \
  --target-host root@[ip]
```

## Add a new host if needed

1. Create `./systems/<hostname>/` with `default.nix`, `disk-layout.nix`, and `hardware-configuration.nix`.
2. `flake.nix` will automatically pick it up with no changes necessary.
3. Add the host's SSH public key to `modules/ssh.nix` if it needs to be an authorized client, and add its own key to the user's `authorizedKeys` list if it needs SSH access to other hosts.

## Requirements

- Nix with flakes and pipe-command enabled.
