{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

        disko.url = "github:nix-community/disko/latest";
        disko.inputs.nixpkgs.follows = "nixpkgs";

        lanzaboote.url = "github:nix-community/lanzaboote";
        lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    };

    outputs = { nixpkgs, self, ... } @ inputs:
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
                ./systems/${hostname}/default.nix
                ./systems/${hostname}/hardware-configuration.nix
            ] ++ sharedModules;
        };

    in {
        nixosConfigurations = lib.readDir ./systems
            |> lib.attrNames
            |> map (n: { name = n; value = mkSystem n; })
            |> lib.listToAttrs;

        nixosModules.security = { imports = securityModules; };
    };
}
