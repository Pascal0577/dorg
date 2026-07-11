{ inputs, ... }:

{
    imports = [ inputs.disko.nixosModules.disko ];

    networking.hostId = "674c9237";
    boot.zfs.forceImportRoot = false;
    services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
    };

    disko.devices.disk = {
        boot = {
            type = "disk";
            device = "/dev/vda";
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

                    root = {
                        size = "100%";
                        content = {
                            type = "zfs";
                            pool = "zboot";
                        };
                    };
                };
            };
        };
    };

    disko.devices.zpool = {
        zboot = {
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
                        "com.sun:auto-snapshot" = "false";
                    };
                };

                "local/root" = {
                    type = "zfs_fs";
                    mountpoint = "/";
                    options."com.sun:auto-snapshot" = "false";
                };

                "local/containers/xmpp" = {
                    type = "zfs_fs";
                    mountpoint = "/var/lib/nixos-containers/xmpp";
                    options = {
                        encryption = "aes-256-gcm";
                        keyformat = "hex";
                        keylocation = "file:///run/zfs_xmpp.key";
                        "com.sun:auto-snapshot" = "true";
                    };
                };
            };
        };
    };
}
