{ inputs, ... }:

{
    imports = [ inputs.disko.nixosModules.disko ];

    networking.hostId = "5eafa8c8";
    boot.zfs.forceImportRoot = false;
    services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
    };

    disko.devices = {
        disk.main = {
            type = "disk";
            device = "/dev/disk/by-id/ata-AirDisk_512GB_SSD_QKF743W013072S302X";
            content = {
                type = "gpt";
                partitions = {
                    esp = {
                        size = "1G";
                        type = "EF00";
                        content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                            mountOptions = [ "umask=0077" ];
                        };
                    };
                    swap = {
                        size = "8G";
                        content = {
                            type = "swap";
                            randomEncryption = true;
                        };
                    };
                    root = {
                        size = "100%";
                        content = {
                            type = "luks";
                            name = "cryptroot";
                            settings.allowDiscards = true;
                            settings.bypassWorkqueues = true;
                            content = {
                                type = "zfs";
                                pool = "zroot";
                            };
                        };
                    };
                };
            };
        };

        zpool.zroot = {
            type = "zpool";
            rootFsOptions = {
                acltype = "posixacl";
                atime = "off";
                compression = "lz4";
                mountpoint = "none";
                xattr = "sa";
                dnodesize = "auto";
            };

            options = {
                ashift = "12";
                autotrim = "on";
            };

            datasets = {
                "local" = {
                    type = "zfs_fs";
                    options.mountpoint = "none";
                };

                "local/nix" = {
                    type = "zfs_fs";
                    mountpoint = "/nix";
                    options = {
                        recordsize = "64K";
                        compression = "zstd";
                        "com.sun:auto-snapshot" = "false";
                    };
                };

                "local/media" = {
                    type = "zfs_fs";
                    mountpoint = "/srv/media";
                    options = {
                        recordsize = "1M";
                        compression = "off";
                        "com.sun:auto-snapshot" = "false";
                    };
                };

                "local/containers/xmpp" = {
                    type = "zfs_fs";
                    mountpoint = "/var/lib/nixos-containers";
                    options = {
                        recordsize = "32K";
                        "com.sun:auto-snapshot" = "true";
                    };
                };

                "local/root" = {
                    type = "zfs_fs";
                    mountpoint = "/";
                    options."com.sun:auto-snapshot" = "false";
                };
            };
        };
    };
}
