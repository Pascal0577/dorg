# dorg's NixOS configs

A flake-based NixOS configuration managing a set of hardened, ZFS-backed headless systems. Going to be used for d.org XMPP.

## Overview

This repository defines the system configuration:

### quill
- Separate boot disk (`zboot`: ESP + swap + ZFS root/nix) and three 8TB drives in a RAIDZ1 pool (`zdata`) for bulk storage and container data.
- Disk encryption not needed (only ever touched by Quill themself).
- No static IP. Could be solved with dynamic DNS.
- Has tons of storage (24TB)

The host run monthly ZFS scrubs and use `lz4`/`zstd` compression tuned per dataset.

The host are built as minimal, headless, hardened NixOS systems using
[disko](https://github.com/nix-community/disko) for declarative disk
partitioning and ZFS pool/dataset layout, and
[lanzaboote](https://github.com/nix-community/lanzaboote) for Secure Boot
support.

## Repo Layout

```
.
├── flake.nix                            # Entry point wires hosts + shared modules together
├── .sops.yaml                           # Define secrets access
├── lib/
│   └── hardened-service.nix             # Shared systemd sandboxing profile (hardening.mkService)
├── modules/                             # Shared NixOS modules, applied to every host
│   ├── boot.nix                         # Kernel, sysctls, boot params
│   ├── meta-settings.nix                # settings for nix
│   ├── networking.nix                   # systemd-networkd, systemd-resolved, firewall
│   ├── reduce-closure-size.nix
│   ├── sops.nix                         # define secrets locations
│   ├── ssh.nix                          # hardened sshd unit service + authorized keys
│   ├── users.nix                        # user account
│   └── security/
│       ├── disable-setuid.nix           # Disables sudo/su/mount setuid wrappers, uses polkit
│       ├── disabled-kernel-modules.nix  # blacklists kernel modules used in dirtyfrag (see Security section)
│       └── hardened-services/           # sandboxes services
│           ├── acpid.nix
│           ├── ...
│           └── zfs-services.nix
├── secrets/                             # Secrets for each host
│   ├── test.yaml
│   └── quill.yaml
├── servers/
│   ├── matrix.nix                       # Matrix server with tuwunel
│   └── xmpp.nix                         # XMPP server configuration and container configuration
└── systems/
    ├── quill/
    │   ├── default.nix                  # Host module imports
    │   ├── disk-layout.nix              # disko: boot pool + 3-disk RAIDZ1 data pool
    │   └── hardware-configuration.nix   # CPU/firmware/initrd settings
    └── test/
        ├── default.nix
        ├── disk-layout.nix
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
- The **XMPP server** defined in `servers/xmpp.nix` runs in a NixOS container with
  [prosody](https://prosody.im/) upon boot. Packets are forwarded from the host to the container.
- The **Matrix server** in `servers/matrix.nix` runs [tuwunel](https://github.com/matrix-construct/tuwunel)

## Secrets Management

Secrets are encrypted at rest with [sops-nix](https://github.com/Mic92/sops-nix) using `age` as the encryption backend.

- **`.sops.yaml`** at the repo root defines which `age` public keys (admins/hosts)
  can decrypt which files, keyed off path regexes matching `secrets/<hostname>.yaml`.
- **`secrets/<hostname>.yaml`** holds each host's encrypted
  secrets (one file per host, e.g. `secrets/quill.yaml`, `secrets/test.yaml`).
  These files are safe to commit. The values are encrypted, only the keys are visible in plaintext.
- **`modules/sops.nix`** wires decrypted secrets into the running system for every host,
  pulling from `secrets/${hostname}.yaml` and placing them at runtime-only paths under `/run/secrets/`
  - `password` - the hashed user password, needed early enough in boot to be used for user creation (`neededForUsers = true`).
  - `zfs_xmpp_key` - key material for unlocking the encrypted ZFS dataset backing the XMPP container.
  - `matrix_env_vars` - environment file with secrets for the `tuwunel` Matrix server.
- **Host `age` key**: each host decrypts its secrets at runtime using a host-specific
  `age` private key expected at `/var/lib/sops-nix/keys.txt` (`sops.age.keyFile`).
  Nothing is decrypted at build time. Decryption happens on-host at activation, gated
  by the `sops-install-secrets` / `sops-install-secrets-for-users` systemd services
  (other units, like ZFS import, correctly `require`/`after` these).

### Bootstrapping a new host
The `mkDeployment` script in `flake.nix` (exposed as `deploy-<hostname>`) handles first-time provisioning

1. Decrypts `zfs_xmpp_key` from `secrets/<hostname>.yaml` locally with `sops` and passes
  it to `nixos-anywhere` as a disk-encryption key for the `kexec`/`disko` phase.
2. Decrypts that host's `age_key` locally and copies it over SSH into
  `/mnt/var/lib/sops-nix/keys.txt` on the target before the final
  `install`/`reboot` phase, so the freshly installed system can immediately decrypt its own secrets on first boot.

### Adding/rotating a secret
1. Edit the relevant host file in place with `sops secrets/<hostname>.yaml` (requires your `age` key to be listed as an admin key for that path in `.sops.yaml`),
2. Add a matching entry in `modules/sops.nix` if it's a new secret
3. Rebuild/switch the host.

### Adding a new host's secrets
1. Generate an `age` keypair for the host, add its public key to `.sops.yaml`
2. Create `secrets/<hostname>.yaml` (`sops secrets/<hostname>.yaml` will create it if it doesn't exist),
  and populate at least `password`, `zfs_xmpp_key`, and `age_key`

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
nixos-rebuild build --flake .#<hostname>

# Deploy to a remote host
nixos-rebuild switch --flake .#<hostname> --target-host dorg@<ip-address> --ask-elevate-password --elevate=run0
```

To install/deploy for the first time on a machine:

```bash
nix build .#deploy-<hostname> && ./result <ip-address>
```

## Add a new host if needed

1. Create `./systems/<hostname>/` with `default.nix`, `disk-layout.nix`, and `hardware-configuration.nix`.
2. `flake.nix` will automatically pick it up with no changes necessary.
3. Add the host's SSH public key to `modules/ssh.nix` if it needs to be an authorized client, and add its own key to the user's `authorizedKeys` list if it needs SSH access to other hosts.

## Requirements

- Nix with flakes and pipe-command enabled.
