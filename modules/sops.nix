{ hostname, ... }:

{
    sops = {
        defaultSopsFile = ../secrets/${hostname}.yaml;
        defaultSopsFormat = "yaml";

        age.keyFile = "/var/lib/sops-nix/key.txt";

        secrets = {
            "password" = {
                neededForUsers = true;
                owner = "root";
            };
        };
    };
}
