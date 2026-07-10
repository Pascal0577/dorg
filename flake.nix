{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

        disko.url = "github:nix-community/disko/latest";
        disko.inputs.nixpkgs.follows = "nixpkgs";

        lanzaboote.url = "github:nix-community/lanzaboote";
        lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

        sops-nix.url = "github:Mic92/sops-nix";
        sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    };

    outputs = { self, nixpkgs, sops-nix, ... } @ inputs:
    let
        lib = nixpkgs.lib;
        hardening = import ./lib/hardened-service.nix { inherit lib; };

        sharedModules = ./modules
            |> nixpkgs.lib.filesystem.listFilesRecursive
            |> builtins.filter (nixpkgs.lib.hasSuffix ".nix");

        securityModules = ./modules/security
            |> nixpkgs.lib.filesystem.listFilesRecursive
            |> builtins.filter (nixpkgs.lib.hasSuffix ".nix");

        mkSystem = hostname: lib.nixosSystem {
            specialArgs = { inherit inputs self hostname hardening; };
            modules = [
                sops-nix.nixosModules.sops
                ./systems/${hostname}/default.nix
                ./systems/${hostname}/hardware-configuration.nix
            ] ++ sharedModules;
        };

        mkDeployment = hostname: nixpkgs.legacyPackages.x86_64-linux.writeShellScript "deploy-${hostname}" ''
            set -e

            ip_addr="$1"
            hostname=${hostname}

            zfs_key=$(sops -d --extract '["zfs_xmpp_key"]' secrets/"$hostname".yaml)
            if [ -z "$zfs_key" ]; then
                echo "ERROR: failed to extract zfs_xmpp_key from secrets/$hostname.yaml" >&2
                exit 1
            fi

            nix run github:nix-community/nixos-anywhere -- \
                --flake .#"$hostname" \
                --phases kexec,disko \
                --disk-encryption-keys /run/zfs_xmpp.key <(echo "$zfs_key") \
                --target-host root@"$ip_addr"

            age_key=$(sops -d --extract '["'"$hostname"'_age_key"]' secrets/bootstrap-keys.yaml)
            if [ -z "$age_key" ]; then
                echo "ERROR: failed to extract ${hostname}_age_key from secrets/bootstrap-keys.yaml" >&2
                exit 1
            fi

            echo "$age_key" | ssh root@"$ip_addr" \
                'mkdir -p /mnt/var/lib/sops-nix && cat > /mnt/var/lib/sops-nix/keys.txt && chmod 600 /mnt/var/lib/sops-nix/keys.txt'

            nix run github:nix-community/nixos-anywhere -- \
                --flake .#"$hostname" \
                --phases install,reboot \
                --target-host root@"$ip_addr"
        '';
    in {
        nixosConfigurations = lib.readDir ./systems
            |> lib.attrNames
            |> map (n: { name = n; value = mkSystem n; })
            |> lib.listToAttrs;

        nixosModules = {
            security = { imports = securityModules; };
            xmpp = {
                imports = [ ./containers/xmpp.nix ];
                _module.args.xmppFlake = self;
            };
        };

        packages.x86_64-linux = lib.readDir ./systems
            |> lib.attrNames
            |> map (n: { name = "deploy-${n}"; value = mkDeployment n; })
            |> lib.listToAttrs;
    };
}
