{ pkgs, inputs, ... }:

{
    imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

    boot = {
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
            "zswap.enabled=1"
            "zswap.compressor=zstd"
            "zswap.max_pool_percent=50"
            "zswap.shrinker_enabled=1"
        ];
    };
}

# More work needs to be done if I want to enable secure boot.
# Here's a quick summary of what I need to do:
# sudo nix-shell -p sbctl
# sudo sbctl create-keys
# Clear all the secure boot keys in the UEFI and enable secure boot there
# sudo sbctl enroll-keys --microsoft
# Re-enable secure boot in UEFI if needed

