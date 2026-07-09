{ self, modulesPath, ... }:

{
    imports = [
        ./disk-layout.nix
        self.nixosModules.xmpp
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/perlless.nix")
        (modulesPath + "/profiles/headless.nix")
    ];
}
