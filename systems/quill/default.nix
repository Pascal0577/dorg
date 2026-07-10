{ self, ... }:

{
    imports = [
        ./disk-layout.nix
        self.nixosModules.xmpp
    ];
}
