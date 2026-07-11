{ inputs, lib, pkgs, hostname, ... }:

{
    imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

    boot = {
        # don't try to decrypt volumes yet
        # the secrets managed by sops aren't on the filesystem yet
        zfs.requestEncryptionCredentials = "false";

        initrd.systemd.enable = true;
        supportedFilesystems = [ "zfs" ];
        kernelPackages = pkgs.linuxKernel.packages.linux_6_18;

        loader = {
            efi.canTouchEfiVariables = true;
            systemd-boot.enable = false;
        };

        lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
            autoGenerateKeys.enable = true;
            autoEnrollKeys.enable = true;
        };

        kernel.sysctl = {
            "kernel.sched_cfs_bandwidth_slice_us" = 3000;
            "net.ipv4.tcp_fin_timeout" = 5;
            "vm.max_map_count" = 2147483642;
        };

        kernelParams = [
            "rcupdate.rcu_expedited=1"
            "page_alloc.shuffle=1"
        ];
    };

    # Make sure we load the encryption key for the container volume
    # before we mount it but after sops is ready
    systemd.services."zfs-load-xmpp-key" = let
        # TODO make this less hacky
        dataset =
            if hostname == "test"
            then "zboot/local/containers/xmpp"
            else "zdata/local/containers/xmpp";

        zfsLoadXmppKey = pkgs.writeShellScript "zfs-load-xmpp-key" ''
            set -e
            zfs=${lib.getExe pkgs.zfs}
            ks=$("$zfs" get -Ho value keystatus ${dataset})
            if [ "$ks" != "available" ]; then
                "$zfs" load-key ${dataset}
            fi
        '';
    in {
        requiredBy = [ "var-lib-nixos\\x2dcontainers-xmpp.mount" ];
        requires = [ "sops-install-secrets.service" "sops-install-secrets-for-users.service" ];
        before = [ "var-lib-nixos\\x2dcontainers-xmpp.mount" ];
        after = [ "sops-install-secrets.service" "sops-install-secrets-for-users.service" "zfs-import.target" ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = zfsLoadXmppKey;
        };
    };
}
