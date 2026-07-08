{ modulesPath, ... }:

{
    imports = [
        ./disk-layout.nix
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/perlless.nix")
        (modulesPath + "/profiles/headless.nix")
    ];
}
