{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

        disko.url = "github:nix-community/disko/latest";
        disko.inputs.nixpkgs.follows = "nixpkgs";

        lanzaboote.url = "github:nix-community/lanzaboote";
        lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    };

    outputs = { nixpkgs, ... } @ inputs:
    let
        sharedModules = ./modules
            |> nixpkgs.lib.filesystem.listFilesRecursive
            |> builtins.filter (nixpkgs.lib.hasSuffix ".nix");
    in {
        nixosConfigurations.dorg = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [ ./hardware-configuration.nix ] ++ sharedModules;
        };
    };
}
