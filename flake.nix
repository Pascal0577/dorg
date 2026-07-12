{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

        disko.url = "github:nix-community/disko/latest";
        disko.inputs.nixpkgs.follows = "nixpkgs";

        lanzaboote.url = "github:nix-community/lanzaboote";
        lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

        sops-nix.url = "github:Mic92/sops-nix";
        sops-nix.inputs.nixpkgs.follows = "nixpkgs";

        nixos-anywhere.url = "github:nix-community/nixos-anywhere";
        nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    };

    outputs = { self, nixpkgs, sops-nix, nixos-anywhere, ... } @ inputs:
    let
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
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

        mkDeployment = hostname: pkgs.writeShellScript "deploy-${hostname}" ''
            set -e
            ip_addr="$1"

            sops_path=${lib.getExe pkgs.sops}
            nixos_anywhere=${nixos-anywhere.packages.x86_64-linux.default}/bin/nixos-anywhere

            zfs_key=$("$sops_path" -d --extract '["zfs_xmpp_key"]' secrets/${hostname}.yaml)
            if [ -z "$zfs_key" ]; then
                echo "ERROR: failed to extract zfs_xmpp_key from secrets/${hostname}.yaml" >&2
                exit 1
            fi

            "$nixos_anywhere" \
                --flake .#${hostname} \
                --phases kexec,disko \
                --disk-encryption-keys /run/zfs_xmpp.key <(echo "$zfs_key") \
                --target-host root@"$ip_addr"

            age_key=$("$sops_path" -d --extract '["age_key"]' secrets/${hostname}.yaml)
            if [ -z "$age_key" ]; then
                echo "ERROR: failed to extract ${hostname}_age_key from secrets/${hostname}.yaml" >&2
                exit 1
            fi

            echo "$age_key" | ssh root@"$ip_addr" \
                'mkdir -p /mnt/var/lib/sops-nix && cat > /mnt/var/lib/sops-nix/keys.txt && chmod 600 /mnt/var/lib/sops-nix/keys.txt'

            "$nixos_anywhere" \
                --flake .#${hostname} \
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
            matrix = { imports = [ ./modules/matrix.nix ]; };
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
