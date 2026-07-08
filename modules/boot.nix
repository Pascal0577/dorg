{ pkgs, ... }:

{
    boot = {
        initrd.systemd.enable = true;
        supportedFilesystems = [ "zfs" ];
        kernelPackages = pkgs.linuxKernel.packages.linux_6_18;
        loader.efi.canTouchEfiVariables = true;

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
