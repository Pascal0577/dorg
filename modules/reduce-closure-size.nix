{ modulesPath, ... }:

{
    imports = [
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
    ];

    boot.initrd.systemd.enable = true;
    system.etc.overlay.enable = true;
    services.userborn.enable = true;
    system.tools.nixos-generate-config.enable = false;
    environment.defaultPackages = [];
}
