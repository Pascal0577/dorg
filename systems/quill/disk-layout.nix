{ inputs, ... }:

{
    imports = [ inputs.disko.nixosModules.disko ];

    networking.hostId = "558676df";
    boot.zfs.forceImportRoot = false;
    services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
    };

    disko.devices.disk = {
        boot = {
            type = "disk";
            device = "/dev/disk/by-id/ata-HFS480G3H2X069N_ESC3N5716I0603O4F";
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
                        size = "16G";
                        content.type = "swap";                            
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

        data1 = {
            type = "disk";
            device = "/dev/disk/by-id/ata-ST8000NM012A-2KE131_WSD3J8TG";
            content = {
                type = "gpt";
                partitions.zfs = {
                    size = "100%";
                    content = {
                        type = "zfs";
                        pool = "zdata";
                    };
                };
            };
        };

        data2 = {
            type = "disk";
            device = "/dev/disk/by-id/ata-ST8000NM012A-2KE131_WSD3J8F1";
            content = {
                type = "gpt";
                partitions.zfs = {
                    size = "100%";
                    content = {
                        type = "zfs";
                        pool = "zdata";
                    };
                };
            };
        };

        data3 = {
            type = "disk";
            device = "/dev/disk/by-id/ata-ST8000NM012A-2KE131_WSD3MV6M";
            content = {
                type = "gpt";
                partitions.zfs = {
                    size = "100%";
                    content = {
                        type = "zfs";
                        pool = "zdata";
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
            };
        };

        zdata = {
            type = "zpool";
            mode = "raidz1";
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

                "local/containers/xmpp" = {
                    type = "zfs_fs";
                    mountpoint = "/var/lib/nixos-containers/xmpp";
                    options."com.sun:auto-snapshot" = "true";
                };
            };
        };
    };
}
