{ hostname, ... }:

{
    sops = {
        defaultSopsFile = ../secrets/${hostname}.yaml;
        defaultSopsFormat = "yaml";

        age.keyFile = "/var/lib/sops-nix/keys.txt";

        secrets = {
            "password" = {
                neededForUsers = true;
                owner = "root";
            };

            "zfs_xmpp_key" = {
                path = "/run/zfs_xmpp.key";
                owner = "root";
                mode = "0400";
            };
        };
    };
}
